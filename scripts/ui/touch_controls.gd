extends Control
## Gesture controls for phones and tablets (the mouse works too, as an emulated finger):
## hold a finger down and the salmon swims towards it, wiggle it back and forth to boost, swipe up
## to jump and down to dive under the surface (up again to come back), and in the air swipe
## any way to spin or flip that way or draw circles to corkscrew.
## Gestures are handed to the salmon through
## the GameInput autoload.

signal pause_pressed

const UI := preload("res://scripts/ui/ui_kit.gd")
const Salmon := preload("res://scripts/player/salmon.gd")

## A touch has to be held this long before the salmon starts following it, so a quick
## swipe at the edge of the screen doesn't also yank the fish sideways.
const HOLD_TIME := 0.1
## Steering is a stick: a drag of STICK_REACH (canvas units, scaled by _k) to one side is full
## left or right, and less than STICK_DEAD of that is no steering at all.
const STICK_REACH := 105.0
const STICK_DEAD := 0.12
## A swipe is at least SWIPE_DIST (canvas units, scaled by _k) travelled within SWIPE_WINDOW seconds.
const SWIPE_DIST := 70.0
const SWIPE_WINDOW := 0.16
## ...but a sideways dash on the water takes a much longer flick in that time.
const DASH_DIST := 190.0
## ...in a straight line: its direction may turn no more than this (radians) on the way. The
## start of a circle covers ground just as fast as a swipe, and only its curve tells them apart.
const SWIPE_STRAIGHT := 0.45
## Circles corkscrew (in the air): the finger's direction has to turn CIRCLE_ON radians (about
## half a loop) within CIRCLE_WINDOW seconds to start, and keep turning to keep going.
const CIRCLE_WINDOW := 0.5
const CIRCLE_ON := 3.0
const CIRCLE_KEEP := 1.5
## Wiggling boosts: the finger has to double back WIGGLE_ON times within WIGGLE_WINDOW seconds
## to start, and keep doubling back to keep going.
const WIGGLE_WINDOW := 0.6
const WIGGLE_ON := 3
const WIGGLE_KEEP := 1
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
var _flips: Array[float] = []  # when the finger last doubled back on itself
var _steady_x := 0.0           # the finger's position with the wiggle smoothed out of it
# Steering is a stick whose middle is where the finger came down. (Where on the screen that
# is makes no difference.)
var _drag_from := 0.0
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
	_steady_x = p.x
	_drag_from = p.x
	_turns.clear()
	_flips.clear()
	_head_pos = p
	_has_head = false
	queue_redraw()


func _release() -> void:
	_touch = -1
	_trail.clear()
	_turns.clear()
	_flips.clear()
	GameInput.roll = 0.0
	GameInput.wiggling = false
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
		# doubling back is a wiggle, not part of a turn
		if absf(turn) < 2.4:
			_turns.append([_now(), turn])
		else:
			_flips.append(_now())
	_head = a
	_has_head = true
	_head_pos = _pos


## How far (radians, signed) the finger's direction has turned in the last `window` seconds.
func _turned(window := CIRCLE_WINDOW) -> float:
	var now := _now()
	while not _turns.is_empty() and now - float(_turns[0][0]) > CIRCLE_WINDOW:
		_turns.pop_front()
	var sum := 0.0
	for s: Array in _turns:
		if now - float(s[0]) > window:
			continue
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
	# a curving stroke is the start of a circle, and a wiggle is a wiggle: neither is a swipe
	if d.length() < need or GameInput.roll != 0.0 or GameInput.wiggling or absf(_turned(SWIPE_WINDOW)) > SWIPE_STRAIGHT:
		return
	# 8-way: each axis counts if it carries a fair share of the stroke
	var n := d.normalized()
	var dir := Vector2(signf(n.x) if absf(n.x) > 0.38 else 0.0, signf(n.y) if absf(n.y) > 0.38 else 0.0)
	var on_water: bool = player != null and not player.in_air()
	if on_water and dir not in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		# on the water only straight up (jump, or come up), straight down (dive) and straight
		# to one side (a dash that way) mean anything
		return
	# A dash has to be meant: a hard, flat flick well past the reach of the steering stick, or
	# every turn would set one off.
	if on_water and dir.y == 0.0 and (d.length() < DASH_DIST * _k() or absf(n.y) > 0.22):
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
	# circles: a corkscrew, turning the way the finger goes round
	var turned := _turned()
	var roll := signf(turned) if absf(turned) > (CIRCLE_KEEP if GameInput.roll != 0.0 else CIRCLE_ON) else 0.0
	# wiggles: boost
	var now := _now()
	while not _flips.is_empty() and now - _flips[0] > WIGGLE_WINDOW:
		_flips.pop_front()
	var wiggling := _flips.size() >= (WIGGLE_KEEP if GameInput.wiggling else WIGGLE_ON)
	if roll != GameInput.roll or wiggling != GameInput.wiggling:
		GameInput.roll = roll
		GameInput.wiggling = wiggling
		queue_redraw()
	# the salmon follows the middle of a wiggle, not every stroke of it
	_steady_x = lerpf(_steady_x, _pos.x, 1.0 - exp(-delta * (5.0 if wiggling else 40.0)))
	_held_for += delta
	if _held_for < HOLD_TIME or player == null or camera == null or view == null:
		return
	# A stick under the thumb: the further the finger is dragged from where it came down, the
	# harder the salmon steers that way, for as long as it is held there.
	var push := clampf((_steady_x - _drag_from) / (STICK_REACH * _k()), -1.0, 1.0)
	if absf(push) < STICK_DEAD:
		push = 0.0
	GameInput.follow = true
	GameInput.follow_dx = push / Salmon.FOLLOW_GAIN


func _draw() -> void:
	var font := UI.font()
	var k := _k()
	if _touch != -1:
		var ring: Color = UI.GOLD if GameInput.wiggling or GameInput.roll != 0.0 else UI.TEAL
		# the stick: its base where the finger came down, and the knob under the finger
		var base := Vector2(_drag_from, _pos.y)
		draw_arc(base, STICK_REACH * k, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 3.0 * k)
		draw_line(base, Vector2(clampf(_pos.x, base.x - STICK_REACH * k, base.x + STICK_REACH * k), base.y), Color(1, 1, 1, 0.3), 6.0 * k)
		draw_circle(_pos, 46.0 * k, Color(ring, 0.18))
		draw_arc(_pos, 46.0 * k, 0.0, TAU, 32, Color(ring, 0.7), (9.0 if GameInput.wiggling or GameInput.roll != 0.0 else 4.0) * k)
	if _flash > 0.0:
		var a := clampf(_flash / 0.35, 0.0, 1.0)
		var tip := _flash_pos + _flash_dir * 90.0 * k
		var side := _flash_dir.orthogonal() * 22.0 * k
		draw_line(_flash_pos - _flash_dir * 40.0 * k, tip, Color(UI.GOLD, a), 8.0 * k)
		draw_colored_polygon(PackedVector2Array([tip + _flash_dir * 30.0 * k, tip + side, tip - side]), Color(UI.GOLD, a))
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
