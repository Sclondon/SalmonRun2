extends Control
## A little pixelated globe for the map and the travel screen. Stages are pins on the Earth,
## and the journey is a red line that draws itself from one to the next while the globe turns
## to follow it, the way the travel maps do in an adventure film.
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

## The globe's radius as a share of the space it has; the rest is its halo of atmosphere.
const ATMOSPHERE := 0.88
const MAX_ZOOM := 16.0

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
## How far the view is closed in (1 is the whole globe), and where it is heading.
var _zoom := 1.0
var _zoom_to := 1.0
var _t := 0.0
var _earth: ColorRect
var _mat: ShaderMaterial
var _window := 100.0
var _pins := {}  # stage -> where its pin was last drawn


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/globe.gdshader")
	_mat.set_shader_parameter("earth", preload("res://textures/earth.png"))
	_mat.set_shader_parameter("radius", ATMOSPHERE)
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


## Stages can be oceans apart or a few miles apart, so the view closes in until the stage
## in hand and the nearest one it connects to are comfortably separate.
func _zoom_for() -> float:
	var here := _stage_vec(_to)
	var nearest := PI
	var others: Array[int] = onward.duplicate()
	if not choices.is_empty():
		others = [choices[choice]]
	if _from != -1 and choices.is_empty():
		others.append(_from)
	elif not _static.is_empty():
		others.append(_static[-1])
	for id in others:
		if id != _to:
			nearest = minf(nearest, here.angle_to(_stage_vec(id)))
	return clampf(0.5 / maxf(nearest, 0.001), 1.0, MAX_ZOOM)


## Where the line has got to.
func _head() -> Vector3:
	if not choices.is_empty():
		# choosing: keep both where you are and the way you're looking at in view
		return _stage_vec(_to).slerp(_stage_vec(choices[choice]), 0.5).normalized()
	if _from == -1:
		return _stage_vec(_to)
	return _stage_vec(_from).slerp(_stage_vec(_to), smoothstep(0.0, 1.0, _progress))


func _draw() -> void:
	var r := (minf(size.x, size.y) * 0.5 - 2.0) * ATMOSPHERE
	var c := size * 0.5
	# turn the Earth so the point of interest faces us (tilting only part of the way to it)
	var lat0 := asin(clampf(_view.y, -1.0, 1.0)) * lerpf(0.75, 1.0, smoothstep(1.0, 2.5, _zoom))
	var lon0 := atan2(_view.x, _view.z)
	var m := Basis(Vector3.RIGHT, lat0) * Basis(Vector3.UP, -lon0)
	# the picture is a little bigger than the globe, to leave room for the atmosphere round it
	var half := r / ATMOSPHERE
	_earth.position = c - Vector2(half, half)
	_earth.size = Vector2(half, half) * 2.0
	_mat.set_shader_parameter("view", m)
	_mat.set_shader_parameter("zoom", _zoom)
	# from here on r is the Earth's radius on screen, which zooming makes bigger than the window
	_window = half
	r *= _zoom
	# the journey: every leg already swum, then the one being drawn
	for i in _static.size() - 1:
		_leg(m, c, r, _stage_vec(_static[i]), _stage_vec(_static[i + 1]), 1.0)
	if _from != -1 and choices.is_empty():
		_leg(m, c, r, _stage_vec(_from), _stage_vec(_to), smoothstep(0.0, 1.0, _progress))
	_pins.clear()
	# pins
	var font := UI.font()
	for id in Levels.LIST.size():
		var p: Vector3 = m * _stage_vec(id)
		if p.z < 0.0 or Vector2(p.x, p.y).length() * r > _window - 6.0:
			continue
		var at := c + Vector2(p.x, -p.y) * r
		var here := id == selected
		var pr := (7.0 + sin(_t * 6.0) * 2.0) if here else 4.0
		_pins[id] = at
		if onward.has(id):
			draw_arc(at, 11.0, 0.0, TAU, 20, UI.INK, 6.0)
			draw_arc(at, 11.0, 0.0, TAU, 20, UI.LIME if id == onward[0] else UI.ORANGE, 3.0)
		draw_circle(at, pr + 2.5, UI.INK)
		draw_circle(at, pr, Color.WHITE if here else UI.CYAN)
	_draw_choices(m, c, r, font)
	if selected != -1 and _progress >= 1.0 and choices.is_empty():
		var p: Vector3 = m * _stage_vec(selected)
		if p.z > 0.0 and Vector2(p.x, p.y).length() * r < _window - 6.0:
			var at := c + Vector2(p.x, -p.y) * r + Vector2(-200.0, -18.0)
			var text: String = Levels.LIST[selected].name
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 22, 8, UI.INK)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 22, Color.WHITE)


## Draws the great-circle line from a to b, as far as `upto` (0..1), skipping the far side.
func _leg(m: Basis, c: Vector2, r: float, a: Vector3, b: Vector3, upto: float, col := UI.RED) -> void:
	var steps := maxi(int(rad_to_deg(a.angle_to(b)) / 3.0), 2)
	var prev := Vector2.ZERO
	var prev_ok := false
	var count := int(ceilf(steps * upto))
	for i in count + 1:
		# lifted a little off the surface so it reads as a line over the map
		var p: Vector3 = m * (a.slerp(b, minf(float(i) / steps, upto)) * 1.02)
		var ok := p.z > 0.0 and Vector2(p.x, p.y).length() * r < _window - 4.0
		var at := c + Vector2(p.x, -p.y) * r
		if ok and prev_ok:
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
	var best_d := 70.0
	for i in choices.size():
		if _pins.has(choices[i]):
			var d: float = (_pins[choices[i]] as Vector2).distance_to(event.position)
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


func _draw_choices(m: Basis, c: Vector2, r: float, font: Font) -> void:
	if choices.is_empty():
		return
	# a faint line to every way on, and a bright one to the way in hand
	var here := _stage_vec(_to)
	for id in locked:
		_leg(m, c, r, here, _stage_vec(id), 1.0, Color(0.5, 0.5, 0.55))
	for i in choices.size():
		if i != choice:
			_leg(m, c, r, here, _stage_vec(choices[i]), 1.0, UI.ORANGE)
	_leg(m, c, r, here, _stage_vec(choices[choice]), 1.0, UI.LIME)
	for id in locked:
		_way(font, id, "LOCKED", Color(0.6, 0.6, 0.65), 8.0)
	for i in choices.size():
		if i != choice:
			_way(font, choices[i], Levels.LIST[choices[i]].name, UI.ORANGE, 9.0)
	_way(font, choices[choice], Levels.LIST[choices[choice]].name, UI.LIME, 12.0 + sin(_t * 6.0) * 2.0)


## One way on: a ring round its pin and its name underneath.
func _way(font: Font, id: int, text: String, col: Color, ring: float) -> void:
	if not _pins.has(id):
		return
	var at: Vector2 = _pins[id]
	draw_arc(at, ring, 0.0, TAU, 24, UI.INK, 7.0)
	draw_arc(at, ring, 0.0, TAU, 24, col, 3.5)
	var pos := at + Vector2(-200.0, ring + 22.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 20, 8, UI.INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 20, col)
