extends Control
## The globe scene behind the map and the travel screen: the Earth in space, with the stages
## as pins and the journey as a red line that draws itself from one to the next while the
## globe turns to follow it, the way the travel maps do in an adventure film.
##
## It fills its whole rect, with the globe at `anchor`. It only ever turns: it does not zoom
## in. Stages that are too close together to tell apart at this size (a few miles, where the
## others are oceans apart) have their pins fanned out round the one you are at instead.
##
## The Earth is NASA's Blue Marble picture (public domain), shrunk to textures/earth.png and
## wrapped on a sphere by shaders/globe.gdshader.

signal arrived
## A way on was picked on the globe (see `choose`).
signal chosen(id: int)
## The highlighted way on changed.
signal pointed(id: int)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Levels := preload("res://scripts/world/levels.gd")

## Ways on closer than this on screen are fanned out to this distance.
const NEAR := 70.0
const GREY := Color(0.6, 0.6, 0.66)

## Where the middle of the globe is (as a share of this control's size) and how big it is
## when the whole of it is in view (as a share of the shorter side).
var anchor := Vector2(0.5, 0.5)
var radius := 0.36
## Pin every stage (the practice map) rather than only the ones the journey touches.
var show_all := false
## Pins, names and lines are drawn this many times bigger (a tall phone screen shows the UI
## small, so they need it).
var ui_scale := 1.0
## The stage the big pin is on and whose name is shown.
var selected := -1
## Stages to ring as the ways on from the selected one.
var onward: Array[int] = []
## Choosing where to go next: the ways on that are open, the ones that were not earned, and
## which open one is highlighted.
var choices: Array[int] = []
var locked: Array[int] = []
## Ways on that were open but not taken (shown greyed out beside the way that was: see the
## travel inset in main.gd).
var passed: Array[int] = []
var choice := 0

var _static: Array[int] = []
var _from := -1
var _to := -1
var _progress := 1.0
var _duration := 1.4
var _view := Vector3(0, 0, 1)
var _t := 0.0
var _earth: ColorRect
var _mat: ShaderMaterial
var _pins := {}  # stage -> where its pin was last drawn
var _fan := {}   # stage -> the angle its pin was fanned out at, for the ones that were


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/globe.gdshader")
	_mat.set_shader_parameter("earth", preload("res://textures/earth.png"))
	_earth = ColorRect.new()
	_earth.material = _mat
	_earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# behind this control's own drawing, so the line and pins go on top of the Earth
	_earth.show_behind_parent = true
	add_child(_earth)


static func to_vec(at: Vector2) -> Vector3:
	var lat := deg_to_rad(at.x)
	var lon := deg_to_rad(at.y)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


static func _stage_vec(id: int) -> Vector3:
	return to_vec(Levels.LIST[id].at)


## Shows the journey so far (`done`, in order) and draws the next leg from `from` to `to`.
## With no `from` it just turns to look at `to`.
func show_path(done: Array[int], from: int, to: int, duration := 1.4) -> void:
	_static = done.duplicate()
	_from = from if from != to else -1
	_to = to
	selected = to
	_duration = duration
	_progress = 0.0 if _from != -1 else 1.0
	if _from != -1 and not is_visible_in_tree():
		_view = _stage_vec(_from)
	queue_redraw()


## Jumps straight to looking at a stage (no turning).
func look_at_stage(id: int) -> void:
	_view = _stage_vec(id)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _progress < 1.0:
		_progress = minf(_progress + delta / _duration, 1.0)
		if _progress >= 1.0:
			arrived.emit()
	if _to != -1:
		_view = _view.slerp(_head(), 1.0 - exp(-delta * 4.0)).normalized()
	queue_redraw()




## What the camera follows: the head of the line, or (choosing) halfway to the way in hand.
func _head() -> Vector3:
	if not choices.is_empty():
		return _stage_vec(_to).slerp(_stage_vec(choices[choice]), 0.5).normalized()
	if _from == -1:
		return _stage_vec(_to)
	return _stage_vec(_from).slerp(_stage_vec(_to), smoothstep(0.0, 1.0, _progress))


func _draw() -> void:
	var c := size * anchor
	var r := minf(size.x, size.y) * radius
	# turn the Earth so the point of interest faces us (tilting only part of the way to it,
	# so north stays up)
	var lat0 := asin(clampf(_view.y, -1.0, 1.0)) * 0.75
	var lon0 := atan2(_view.x, _view.z)
	var m := Basis(Vector3.RIGHT, lat0) * Basis(Vector3.UP, -lon0)
	_earth.position = Vector2.ZERO
	_earth.size = size
	_mat.set_shader_parameter("view", m)
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("center", c)
	_mat.set_shader_parameter("globe_radius", r)
	# where every stage is on screen (those round the back are left out)
	_pins.clear()
	for id in Levels.LIST.size():
		var p: Vector3 = m * _stage_vec(id)
		if p.z > 0.0:
			_pins[id] = c + Vector2(p.x, -p.y) * r
	_spread_ways()
	# the journey: every leg already swum, then the one being drawn
	for i in _static.size() - 1:
		_leg(m, c, r, _stage_vec(_static[i]), _stage_vec(_static[i + 1]), 1.0)
	if _from != -1 and choices.is_empty():
		_leg(m, c, r, _stage_vec(_from), _stage_vec(_to), smoothstep(0.0, 1.0, _progress))
	# the ways not taken from where the leg sets out: greyed out, and dashed
	if choices.is_empty() and _from != -1:
		for id in locked + passed:
			_leg(m, c, r, _stage_vec(_from), _stage_vec(id), 1.0, GREY, true)
	# the ways on are only possibilities until one is picked, so they are dashed
	if not choices.is_empty():
		for id in locked:
			_way(m, c, r, id, GREY)
		for i in choices.size():
			if i != choice:
				_way(m, c, r, choices[i], UI.OCHRE)
		_way(m, c, r, choices[choice], UI.GOLD)
	# pins: the plain ones first, then the ones that matter on top
	var font := UI.font()
	for id: int in _pins:
		var plain := id != selected and not choices.has(id) and not locked.has(id) and not onward.has(id)
		if plain and (show_all or _static.has(id)):
			_pin(_pins[id], UI.TEAL, 0.75)
	for id in onward:
		_pin_named(font, id, "", UI.GOLD if id == onward[0] else UI.OCHRE, 0.9)
	for id in passed:
		_pin_named(font, id, Levels.LIST[id].name, GREY, 0.8)
	for id in locked:
		_pin_named(font, id, "LOCKED", GREY, 0.9)
	for i in choices.size():
		if i != choice:
			_pin_named(font, choices[i], Levels.LIST[choices[i]].name, UI.OCHRE, 1.0)
	if selected != -1:
		_pin_named(font, selected, Levels.LIST[selected].name if choices.is_empty() and _progress >= 1.0 else "",
				Color.WHITE, 1.15)
	if not choices.is_empty():
		_pin_named(font, choices[choice], Levels.LIST[choices[choice]].name, UI.GOLD, 1.3 + sin(_t * 6.0) * 0.08)


## A map pin: a round head on a point that sits exactly on the place.
func _pin(at: Vector2, col: Color, k: float) -> void:
	k *= ui_scale
	var head := at + Vector2(0.0, -22.0 * k)
	var hr := 9.0 * k
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, 3.0 * k), head + Vector2(-hr - 2.5, 3.0 * k), head + Vector2(hr + 2.5, 3.0 * k)]), UI.INK)
	draw_circle(head, hr + 2.5, UI.INK)
	draw_colored_polygon(PackedVector2Array([at, head + Vector2(-hr * 0.8, 4.0 * k), head + Vector2(hr * 0.8, 4.0 * k)]), col)
	draw_circle(head, hr, col)
	draw_circle(head, hr * 0.38, UI.INK)


func _pin_named(font: Font, id: int, text: String, col: Color, k: float) -> void:
	if not _pins.has(id):
		return
	var at: Vector2 = _pins[id]
	_pin(at, col, k)
	if text == "":
		return
	var fs := int(20.0 * ui_scale)
	# underneath, unless the pin was fanned out: then on its outer side, clear of the others
	var pos := at + Vector2(-400.0, 4.0 + fs)
	var align := HORIZONTAL_ALIGNMENT_CENTER
	if _fan.has(id):
		var side := cos(float(_fan[id]))
		var up := -22.0 * k * ui_scale + fs * 0.35
		if side > 0.3:
			pos = at + Vector2(14.0 * ui_scale, up)
			align = HORIZONTAL_ALIGNMENT_LEFT
		elif side < -0.3:
			pos = at + Vector2(-800.0 - 14.0 * ui_scale, up)
			align = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			pos = at + Vector2(-400.0, -36.0 * k * ui_scale)
	draw_string_outline(font, pos, text, align, 800.0, fs, int(8.0 * ui_scale), UI.INK)
	draw_string(font, pos, text, align, 800.0, fs, col)


## Draws the great-circle line from a to b, as far as `upto` (0..1), skipping the far side.
func _leg(m: Basis, c: Vector2, r: float, a: Vector3, b: Vector3, upto: float, col := UI.RED, dashed := false) -> void:
	# short enough steps that the curve is smooth and dashes come out even at any zoom
	var steps := clampi(int(a.angle_to(b) * r / 5.0), 8, 600)
	var prev := Vector2.ZERO
	var prev_ok := false
	var run := 0.0
	var count := int(ceilf(steps * upto))
	for i in count + 1:
		# lifted a little off the surface so it reads as a line over the map
		var p: Vector3 = m * (a.slerp(b, minf(float(i) / steps, upto)) * 1.02)
		var ok := p.z > 0.0
		var at := c + Vector2(p.x, -p.y) * r
		if ok and prev_ok:
			run += prev.distance_to(at)
			if not dashed or fmod(run, 22.0 * ui_scale) < 12.0 * ui_scale:
				draw_line(prev, at, UI.INK, 8.0 * ui_scale)
				draw_line(prev, at, col, 4.0 * ui_scale)
		prev = at
		prev_ok = ok
	if upto < 1.0 and prev_ok:
		draw_circle(prev, 7.0 * ui_scale, UI.INK)
		draw_circle(prev, 4.5 * ui_scale, Color.WHITE)


# ------------------------------------------------------------------ choosing the way on

## Shows the journey so far ending at `here`, and lets the player pick the next stage from
## `open` (left / right or a tap on a pin; `chosen` is emitted when one is confirmed by tapping
## it again). `shut` are ways on that were not earned: shown, but not selectable.
func choose(done: Array[int], here: int, open: Array[int], shut: Array[int]) -> void:
	show_path(done, -1, here)
	onward = []
	choices = open.duplicate()
	locked = shut.duplicate()
	choice = 0
	mouse_filter = Control.MOUSE_FILTER_STOP


func stop_choosing() -> void:
	choices = []
	passed = []
	locked = []
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _point(index: int) -> void:
	choice = posmod(index, choices.size())
	pointed.emit(choices[choice])


func _input(event: InputEvent) -> void:
	if choices.size() < 2 or not is_visible_in_tree():
		return
	for action: String in ["ui_left", "ui_up", "steer_left"]:
		if event.is_action_pressed(action):
			_point(choice - 1)
			get_viewport().set_input_as_handled()
			return
	for action: String in ["ui_right", "ui_down", "steer_right"]:
		if event.is_action_pressed(action):
			_point(choice + 1)
			get_viewport().set_input_as_handled()
			return


func _gui_input(event: InputEvent) -> void:
	if choices.is_empty() or not (event is InputEventMouseButton and event.pressed):
		return
	# the nearest way on to the tap: point at it, or go if it is already the one
	var best := -1
	var best_d := 80.0 * ui_scale
	for i in choices.size():
		if _pins.has(choices[i]):
			var d: float = ((_pins[choices[i]] as Vector2) + Vector2(0.0, -14.0 * ui_scale)).distance_to(event.position)
			if d < best_d:
				best_d = d
				best = i
	if best == -1:
		return
	accept_event()
	if best == choice:
		chosen.emit(choices[choice])
	else:
		_point(best)


## Looks at the next (1) or previous (-1) way on, for the arrows beside the picture.
func step(dir: int) -> void:
	if choices.size() > 1:
		_point(choice + dir)


## Moves the pins of ways on that sit almost on top of where you are out into a fan above it,
## so they can be told apart and tapped.
func _spread_ways() -> void:
	_fan.clear()
	if choices.is_empty() or not _pins.has(_to):
		return
	var here: Vector2 = _pins[_to]
	var close: Array[int] = []
	for id: int in choices + locked:
		if _pins.has(id) and (_pins[id] as Vector2).distance_to(here) < NEAR * ui_scale:
			close.append(id)
	for i in close.size():
		# spread evenly either side of straight up
		var a := -PI * 0.5 + (i - (close.size() - 1) * 0.5) * deg_to_rad(100.0 if close.size() < 3 else 80.0)
		_fan[close[i]] = a
		_pins[close[i]] = here + Vector2(cos(a), sin(a)) * NEAR * 1.2 * ui_scale


## The dashed line to one way on: along the Earth, or straight to its pin if it was fanned out.
func _way(m: Basis, c: Vector2, r: float, id: int, col: Color) -> void:
	if not _fan.has(id):
		_leg(m, c, r, _stage_vec(_to), _stage_vec(id), 1.0, col, true)
		return
	var from: Vector2 = _pins[_to]
	var to: Vector2 = _pins[id]
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(length, 0.001)
	var at := 0.0
	while at < length:
		var a := from + dir * at
		var b := from + dir * minf(at + 12.0 * ui_scale, length)
		draw_line(a, b, UI.INK, 8.0 * ui_scale)
		draw_line(a, b, col, 4.0 * ui_scale)
		at += 22.0 * ui_scale
