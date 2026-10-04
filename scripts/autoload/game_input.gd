extends Node
## Registers every gameplay action at startup (keyboard + gamepad) so the project works
## without hand-editing the Input Map.

const KEYS := {
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"swim_up": [KEY_W, KEY_UP],
	"swim_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"boost": [KEY_SHIFT],
	"roll_left": [KEY_Q],
	"roll_right": [KEY_E],
	"grab_1": [KEY_J],
	"grab_2": [KEY_K],
	"grab_3": [KEY_L],
	"grab_4": [KEY_I],
	"pause": [KEY_ESCAPE, KEY_P],
}

const PAD_BUTTONS := {
	"steer_left": [JOY_BUTTON_DPAD_LEFT],
	"steer_right": [JOY_BUTTON_DPAD_RIGHT],
	"swim_up": [JOY_BUTTON_DPAD_UP],
	"swim_down": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A],
	"roll_left": [JOY_BUTTON_LEFT_SHOULDER],
	"roll_right": [JOY_BUTTON_RIGHT_SHOULDER],
	"grab_1": [JOY_BUTTON_X],
	"grab_2": [JOY_BUTTON_Y],
	"grab_3": [JOY_BUTTON_B],
	"pause": [JOY_BUTTON_START],
}

# action -> [axis, direction]
const PAD_AXES := {
	"steer_left": [JOY_AXIS_LEFT_X, -1.0],
	"steer_right": [JOY_AXIS_LEFT_X, 1.0],
	"swim_up": [JOY_AXIS_LEFT_Y, -1.0],
	"swim_down": [JOY_AXIS_LEFT_Y, 1.0],
	"boost": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"grab_4": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


func _ready() -> void:
	for action: String in KEYS:
		_ensure(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in PAD_BUTTONS:
		_ensure(action)
		for button: int in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
	for action: String in PAD_AXES:
		_ensure(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = PAD_AXES[action][0]
		ev.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


# ------------------------------------------------------------------ touch gestures
# Written by the touch controls, read by the salmon.

## A finger is held down: the salmon swims towards it.
var follow := false
## How far the finger is from the salmon, in metres across the river (+ is river-right).
var follow_dx := 0.0
## The finger is drawing little circles: boost.
var circling := false

var _swipes: Array[Vector2] = []


## Queues a swipe. `dir` is 8-way in screen space: x is -1/0/1 (right is +), y is -1/0/1 (down is +).
func swipe(dir: Vector2) -> void:
	_swipes.append(dir)


## Returns the swipes made since the last call.
func take_swipes() -> Array[Vector2]:
	var out := _swipes
	_swipes = []
	return out


func clear_touch() -> void:
	follow = false
	follow_dx = 0.0
	circling = false
	_swipes = []
