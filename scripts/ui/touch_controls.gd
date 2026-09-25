extends Control
## On-screen controls for phones and tablets: a floating stick anywhere on the left half and
## action buttons on the right. They press the same input actions as the keyboard/gamepad
## (via Input.action_press), so the salmon code doesn't know the difference.

signal pause_pressed

const UI := preload("res://scripts/ui/ui_kit.gd")

const STICK_RADIUS := 110.0
const DEAD_ZONE := 0.15
# offsets are from the bottom-right corner; "portrait" overrides the offset on tall screens
const BUTTONS := [
	{"action": "jump", "label": "JUMP", "offset": Vector2(-170, -170), "radius": 95.0, "color": UI.LIME},
	{"action": "grab_1", "label": "GRAB", "offset": Vector2(-365, -120), "radius": 64.0, "color": UI.PINK},
	{"action": "grab_2", "label": "TWEAK", "offset": Vector2(-340, -305), "radius": 60.0, "color": UI.ORANGE},
	{"action": "roll_right", "label": "ROLL", "offset": Vector2(-150, -385), "radius": 60.0, "color": UI.CYAN},
	{"action": "boost", "label": "BOOST", "offset": Vector2(-545, -110), "portrait": Vector2(-170, -580), "radius": 60.0, "color": UI.CYAN},
]
const PAUSE_RADIUS := 36.0

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _held := {}  # touch index -> button index


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_all()


func _button_center(i: int) -> Vector2:
	var k := _k()
	var offset: Vector2 = BUTTONS[i].get("portrait", BUTTONS[i].offset) if k > 1.0 else BUTTONS[i].offset
	return size + offset * k


func _pause_center() -> Vector2:
	return Vector2(size.x * 0.5 + 290.0, 44.0 * _k())


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var p := (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			_touch_down(event.index, p)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_stick_pos = (make_input_local(event) as InputEventScreenDrag).position
		_apply_stick()
		queue_redraw()


func _touch_down(index: int, p: Vector2) -> void:
	for i in BUTTONS.size():
		if p.distance_to(_button_center(i)) < float(BUTTONS[i].radius) * _k() * 1.15:
			_held[index] = i
			Input.action_press(BUTTONS[i].action)
			queue_redraw()
			return
	if p.distance_to(_pause_center()) < PAUSE_RADIUS * _k() * 1.4:
		pause_pressed.emit()
		return
	if p.x < size.x * 0.5 and _stick_touch == -1:
		_stick_touch = index
		_stick_origin = p
		_stick_pos = p
		queue_redraw()


func _touch_up(index: int) -> void:
	if _held.has(index):
		Input.action_release(BUTTONS[_held[index]].action)
		_held.erase(index)
		queue_redraw()
	if index == _stick_touch:
		_stick_touch = -1
		_axis(0.0, "steer_left", "steer_right")
		_axis(0.0, "swim_down", "swim_up")
		queue_redraw()


func _apply_stick() -> void:
	var v := (_stick_pos - _stick_origin) / (STICK_RADIUS * _k())
	if v.length() > 1.0:
		v = v.normalized()
	_axis(v.x, "steer_left", "steer_right")
	_axis(-v.y, "swim_down", "swim_up")


func _axis(value: float, negative: String, positive: String) -> void:
	if value > DEAD_ZONE:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < -DEAD_ZONE:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release_all() -> void:
	for index: int in _held:
		Input.action_release(BUTTONS[_held[index]].action)
	_held.clear()
	_stick_touch = -1
	for action: String in ["steer_left", "steer_right", "swim_up", "swim_down"]:
		Input.action_release(action)


func _draw() -> void:
	var font := UI.font()
	var k := _k()
	var stick_r := STICK_RADIUS * k
	# stick: where the thumb landed, or a hint where it usually goes
	var base := _stick_origin if _stick_touch != -1 else Vector2(size.x * 0.17 * (1.2 if k > 1.0 else 1.0), size.y - 200.0 * k)
	var knob := base
	if _stick_touch != -1:
		knob = base + (_stick_pos - base).limit_length(stick_r)
	draw_circle(base, stick_r, Color(0, 0, 0, 0.3))
	draw_arc(base, stick_r, 0.0, TAU, 40, Color(UI.CYAN, 0.6), 4.0 * k)
	draw_circle(knob, 46.0 * k, Color(UI.CYAN, 0.55 if _stick_touch != -1 else 0.3))
	if _stick_touch == -1:
		_label(font, base + Vector2(0, stick_r + 34.0 * k), "STEER / FLIP", int(22 * k), Color(1, 1, 1, 0.6))
	for i in BUTTONS.size():
		var b: Dictionary = BUTTONS[i]
		var c := _button_center(i)
		var r := float(b.radius) * k
		var held := _held.values().has(i)
		var col: Color = b.color
		draw_circle(c, r, Color(col, 0.55 if held else 0.22))
		draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.9), 4.0 * k)
		_label(font, c, b.label, int((30 if float(b.radius) > 80.0 else 22) * k), Color.WHITE)
	var pc := _pause_center()
	draw_circle(pc, PAUSE_RADIUS * k, Color(0, 0, 0, 0.35))
	draw_arc(pc, PAUSE_RADIUS * k, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0 * k)
	draw_rect(Rect2(pc + Vector2(-12, -14) * k, Vector2(8, 28) * k), Color.WHITE)
	draw_rect(Rect2(pc + Vector2(4, -14) * k, Vector2(8, 28) * k), Color.WHITE)


func _label(font: Font, center: Vector2, text: String, font_size: int, col: Color) -> void:
	var w := 400.0
	draw_string_outline(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 6, UI.INK)
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, col)


## Portrait phones show the 1280-wide UI small, so make the controls thumb-sized again.
func _k() -> float:
	return 1.7 if size.y > size.x else 1.0
