extends Control
## The globe scene behind the map and the travel screen: the Earth in space, with the stages
## as pins and the journey as a red line that draws itself from one to the next while the
## globe turns to follow it, the way the travel maps do in an adventure film.
##
## It fills its whole rect. The globe sits at `anchor` and the camera zooms in on it: stages
## can be oceans or a few miles apart, so it closes in until the ones in hand are clear of
## each other, and the globe simply grows past the edges of the screen.
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

const MAX_ZOOM := 16.0
const GREY := Color(0.6, 0.6, 0.66)

## Where the middle of the globe is (as a share of this control's size) and how big it is
## when the whole of it is in view (as a share of the shorter side).
var anchor := Vector2(0.5, 0.5)
var radius := 0.36
## Pin every stage (the practice map) rather than only the ones the journey touches.
var show_all := false
## The stage the big pin is on and whose name is shown.
var selected := -1
## Stages to ring as the ways on from the selected one.
var onward: Array[int] = []
## Choosing where to go next: the ways on that are open, the ones that were not earned, and
## which open one is highlighted.
var choices: Array[int] = []
var locked: Array[int] = []
var choice := 0

var _static: Array[int] = []
var _from := -1
var _to := -1
var _progress := 1.0
var _duration := 1.4
var _view := Vector3(0, 0, 1)
## How close the camera is (1 is the whole globe in view), and where it is heading.
var _zoom := 1.0
var _zoom_to := 1.0
var _t := 0.0
var _earth: ColorRect
var _mat: ShaderMaterial
var _pins := {}  # stage -> where its pin was last drawn


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
	_zoom_to = _zoom_for()
	if _from != -1 and not is_visible_in_tree():
		_view = _stage_vec(_from)
	queue_redraw()


## Jumps straight to looking at a stage (no turning).
func look_at_stage(id: int) -> void:
	_view = _stage_vec(id)
	_zoom = _zoom_to


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _progress < 1.0:
		_progress = minf(_progress + delta / _duration, 1.0)
		if _progress >= 1.0:
			arrived.emit()
	_zoom = exp(lerpf(log(_zoom), log(_zoom_to), 1.0 - exp(-delta * 3.0)))
	if _to != -1:
		_view = _view.slerp(_head(), 1.0 - exp(-delta * 4.0)).normalized()
	queue_redraw()


## How close to come: enough that the stage in hand and the nearest one it connects to are
## comfortably apart.
func _zoom_for() -> float:
	var here := _stage_vec(_to)
	var nearest := PI
	var others: Array[int] = onward.duplicate()
	if not choices.is_empty():
		others = [choices[choice]]
	elif _from != -1:
		others.append(_from)
	elif not _static.is_empty():
		others.append(_static[-1])
	for id in others:
		if id != _to:
			nearest = minf(nearest, here.angle_to(_stage_vec(id)))
	return clampf(0.5 / maxf(nearest, 0.001), 1.0, MAX_ZOOM)


## What the camera follows: the head of the line, or (choosing) halfway to the way in hand.
func _head() -> Vector3:
	if not choices.is_empty():
		return _stage_vec(_to).slerp(_stage_vec(choices[choice]), 0.5).normalized()
	if _from == -1:
		return _stage_vec(_to)
	return _stage_vec(_from).slerp(_stage_vec(_to), smoothstep(0.0, 1.0, _progress))


func _draw() -> void:
	var c := size * anchor
	var r := minf(size.x, size.y) * radius * _zoom
	# turn the Earth so the point of interest faces us (tilting only part of the way to it
	# from far out, so north stays up)
	var lat0 := asin(clampf(_view.y, -1.0, 1.0)) * lerpf(0.75, 1.0, smoothstep(1.0, 2.5, _zoom))
	var lon0 := atan2(_view.x, _view.z)
	var m := Basis(Vector3.RIGHT, lat0) * Basis(Vector3.UP, -lon0)
	_earth.position = Vector2.ZERO
	_earth.size = size
	_mat.set_shader_parameter("view", m)
	_mat.set_shader_parameter("zoom", _zoom)
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("center", c)
	_mat.set_shader_parameter("globe_radius", r)
	# where every stage is on screen (those round the back are left out)
	_pins.clear()
	for id in Levels.LIST.size():
		var p: Vector3 = m * _stage_vec(id)
		if p.z > 0.0:
			_pins[id] = c + Vector2(p.x, -p.y) * r
	# the journey: every leg already swum, then the one being drawn
	for i in _static.size() - 1:
		_leg(m, c, r, _stage_vec(_static[i]), _stage_vec(_static[i + 1]), 1.0)
	if _from != -1 and choices.is_empty():
		_leg(m, c, r, _stage_vec(_from), _stage_vec(_to), smoothstep(0.0, 1.0, _progress))
	# the ways on are only possibilities until one is picked, so they are dashed
	if not choices.is_empty():
		var here := _stage_vec(_to)
		for id in locked:
			_leg(m, c, r, here, _stage_vec(id), 1.0, GREY, true)
		for i in choices.size():
			if i != choice:
				_leg(m, c, r, here, _stage_vec(choices[i]), 1.0, UI.OCHRE, true)
		_leg(m, c, r, here, _stage_vec(choices[choice]), 1.0, UI.GOLD, true)
	# pins: the plain ones first, then the ones that matter on top
	var font := UI.font()
	for id: int in _pins:
		var plain := id != selected and not choices.has(id) and not locked.has(id) and not onward.has(id)
		if plain and (show_all or _static.has(id)):
			_pin(_pins[id], UI.TEAL, 0.75)
	for id in onward:
		_pin_named(font, id, "", UI.GOLD if id == onward[0] else UI.OCHRE, 0.9)
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
	var pos := at + Vector2(-200.0, 24.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 20, 8, UI.INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 20, col)


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
			if not dashed or fmod(run, 22.0) < 12.0:
				draw_line(prev, at, UI.INK, 8.0)
				draw_line(prev, at, col, 4.0)
		prev = at
		prev_ok = ok
	if upto < 1.0 and prev_ok:
		draw_circle(prev, 7.0, UI.INK)
		draw_circle(prev, 4.5, Color.WHITE)


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
	_zoom_to = _zoom_for()


func stop_choosing() -> void:
	choices = []
	locked = []
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _point(index: int) -> void:
	choice = posmod(index, choices.size())
	_zoom_to = _zoom_for()
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
	var best_d := 80.0
	for i in choices.size():
		if _pins.has(choices[i]):
			var d: float = ((_pins[choices[i]] as Vector2) + Vector2(0.0, -14.0)).distance_to(event.position)
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
