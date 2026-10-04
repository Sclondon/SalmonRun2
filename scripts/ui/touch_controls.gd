extends Control
## Gesture controls for phones and tablets (the mouse works too, as an emulated finger):
## hold a finger down and the salmon swims towards it, draw little circles to boost, swipe up
## to jump, and swipe in any
## direction in the air to spin or flip that way. Gestures are handed to the salmon through
## the GameInput autoload.

signal pause_pressed

const UI := preload("res://scripts/ui/ui_kit.gd")
const Salmon := preload("res://scripts/player/salmon.gd")

## A touch has to be held this long before the salmon starts following it, so a quick
## swipe at the edge of the screen doesn't also yank the fish sideways.
const HOLD_TIME := 0.1
## A swipe is at least SWIPE_DIST (canvas units, scaled by _k) travelled within SWIPE_WINDOW seconds.
const SWIPE_DIST := 70.0
const SWIPE_WINDOW := 0.16
## Little circles boost: the finger's direction has to turn CIRCLE_ON radians (about three
## quarters of a loop) within CIRCLE_WINDOW seconds to start, and keep turning to keep going.
const CIRCLE_WINDOW := 0.7
const CIRCLE_ON := 4.7
const CIRCLE_KEEP := 2.2
const PAUSE_RADIUS := 36.0

var player: Salmon
var camera: Camera3D
## The SubViewportContainer the game is rendered in (its viewport is smaller than the screen).
var view: SubViewportContainer
## Shown along the bottom of the screen (practice uses it to explain the controls).
var hint := "":
	set(v):
		hint = v
		queue_redraw()

var _touch := -1
var _pos := Vector2.ZERO
var _held_for := 0.0
var _trail: Array = []  # [time, position] samples from the last SWIPE_WINDOW seconds
var _armed := true
var _turns: Array = []  # [time, radians the finger's direction turned] samples
var _head_pos := Vector2.ZERO
var _head := 0.0
var _has_head := false
var _flash := 0.0
var _flash_dir := Vector2.ZERO
var _flash_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _pause_center() -> Vector2:
	return Vector2(size.x - 60.0 * _k(), 150.0 * _k())


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var p := (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			_touch_down(event.index, p)
		elif event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_pos = (make_input_local(event) as InputEventScreenDrag).position
		_track_circle()
		_track_swipe()
		queue_redraw()


func _touch_down(index: int, p: Vector2) -> void:
	if p.distance_to(_pause_center()) < PAUSE_RADIUS * _k() * 1.4:
		pause_pressed.emit()
		return
	if _touch != -1:
		return
	_touch = index
	_pos = p
	_held_for = 0.0
	_armed = true
	_trail = [[_now(), p]]
	_turns.clear()
	_head_pos = p
	_has_head = false
	queue_redraw()


func _release() -> void:
	_touch = -1
	_trail.clear()
	_turns.clear()
	GameInput.circling = false
	GameInput.follow = false
	GameInput.follow_dx = 0.0
	queue_redraw()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Records how much the finger's direction of travel turns, one sample every few units moved.
func _track_circle() -> void:
	var d := _pos - _head_pos
	if d.length() < 8.0 * _k():
		return
	var a := d.angle()
	if _has_head:
		var turn := wrapf(a - _head, -PI, PI)
		# scrubbing back and forth is a reversal, not a turn
		if absf(turn) < 2.4:
			_turns.append([_now(), turn])
	_head = a
	_has_head = true
	_head_pos = _pos


## How far (radians, signed) the finger's direction has turned in the last CIRCLE_WINDOW seconds.
func _turned() -> float:
	var now := _now()
	while not _turns.is_empty() and now - float(_turns[0][0]) > CIRCLE_WINDOW:
		_turns.pop_front()
	var sum := 0.0
	for s: Array in _turns:
		sum += float(s[1])
	return sum


## Looks at how far the finger has moved in the last SWIPE_WINDOW seconds. One fast stroke
## is one swipe: it has to slow down again before the next one counts.
func _track_swipe() -> void:
	var now := _now()
	_trail.append([now, _pos])
	while _trail.size() > 1 and now - float(_trail[0][0]) > SWIPE_WINDOW:
		_trail.pop_front()
	var d: Vector2 = _pos - (_trail[0][1] as Vector2)
	var need := SWIPE_DIST * _k()
	if not _armed:
		_armed = d.length() < need * 0.4
		return
	# a curving stroke is part of a circle, not a swipe
	if d.length() < need or GameInput.circling or absf(_turned()) > 1.5:
		return
	# 8-way: each axis counts if it carries a fair share of the stroke
	var n := d.normalized()
	var dir := Vector2(signf(n.x) if absf(n.x) > 0.38 else 0.0, signf(n.y) if absf(n.y) > 0.38 else 0.0)
	if player and not player.in_air() and dir != Vector2.UP:
		# on the water only a straight swipe up means anything; sideways is just steering
		return
	_armed = false
	_flash = 0.35
	_flash_dir = dir.normalized()
	_flash_pos = _pos
	GameInput.swipe(dir)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	if _touch == -1:
		return
	var circling := absf(_turned()) > (CIRCLE_KEEP if GameInput.circling else CIRCLE_ON)
	if circling != GameInput.circling:
		GameInput.circling = circling
		queue_redraw()
	_held_for += delta
	if _held_for < HOLD_TIME or player == null or camera == null or view == null:
		return
	# Where the salmon is on screen, and how many screen units one metre across the river is
	var k := float(view.stretch_shrink)
	var here := player.global_position
	var fish_x := camera.unproject_position(here).x * k
	var metre := (camera.unproject_position(here + player.track.right(player.s)).x * k) - fish_x
	if metre < 1.0:
		return
	GameInput.follow = true
	GameInput.follow_dx = (_pos.x - fish_x) / metre


func _draw() -> void:
	var font := UI.font()
	var k := _k()
	if _touch != -1:
		var ring: Color = UI.LIME if GameInput.circling else UI.CYAN
		draw_circle(_pos, 46.0 * k, Color(ring, 0.18))
		draw_arc(_pos, 46.0 * k, 0.0, TAU, 32, Color(ring, 0.7), (9.0 if GameInput.circling else 4.0) * k)
	if _flash > 0.0:
		var a := clampf(_flash / 0.35, 0.0, 1.0)
		var tip := _flash_pos + _flash_dir * 90.0 * k
		var side := _flash_dir.orthogonal() * 22.0 * k
		draw_line(_flash_pos - _flash_dir * 40.0 * k, tip, Color(UI.LIME, a), 8.0 * k)
		draw_colored_polygon(PackedVector2Array([tip + _flash_dir * 30.0 * k, tip + side, tip - side]), Color(UI.LIME, a))
	if hint != "":
		var lines := hint.split("\n")
		var fs := int(24 * k)
		for i in lines.size():
			_label(font, Vector2(size.x * 0.5, size.y - (90.0 + (lines.size() - 1 - i) * 34.0) * k), lines[i], fs, Color(1, 1, 1, 0.85))
	var pc := _pause_center()
	draw_circle(pc, PAUSE_RADIUS * k, Color(0, 0, 0, 0.35))
	draw_arc(pc, PAUSE_RADIUS * k, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0 * k)
	draw_rect(Rect2(pc + Vector2(-12, -14) * k, Vector2(8, 28) * k), Color.WHITE)
	draw_rect(Rect2(pc + Vector2(4, -14) * k, Vector2(8, 28) * k), Color.WHITE)


func _label(font: Font, center: Vector2, text: String, font_size: int, col: Color) -> void:
	var w := size.x
	draw_string_outline(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 6, UI.INK)
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, col)


## Portrait phones show the 1280-wide UI small, so make the controls thumb-sized again.
func _k() -> float:
	return 1.7 if size.y > size.x else 1.0
