extends Control
## The water lab: the salmon swims a stage on its own while a panel of sliders changes the
## water shader as you watch. What is set here is the stage's own preset: it is used on that
## stage and no other, and SAVE (or BACK, or going to another stage) writes every stage's
## preset into the project (see Track.write_presets), so that they go out with the game.
## A tool for the desktop: the web build has no way in.

signal closed
## Asks for another stage to look at (-1 or 1).
signal stage_stepped(dir: int)
## Asks for the camera to go with the salmon (true) or to stand still over the water.
signal follow_changed(on: bool)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Track := preload("res://scripts/world/track.gd")

## The settings, in the order shown: [uniform, least, most]. A null least marks a colour.
## Headings are a lone string. They are named and grouped just as they are in the water
## shader (so as the Inspector shows them, in the editor: see scenes/water_scene.tscn); only
## WAKE LIFE is not one of the shader's own. The ends of a slider are only where it stops:
## any number at all can be typed into the box beside it.
const ROWS := [
	"COLOUR",
	["deep", null, null],
	["shallow", null, null],
	["foam_color", null, null],
	["depth_range", 0.2, 200.0],
	["alpha_shallow", 0.0, 1.0],
	["alpha_deep", 0.0, 1.0],
	["colour_ripple", 0.0, 1.0],
	["view_clear", 0.0, 1.0],
	"FOAM (DRIFTING PATCHES, BANKS, RIMS)",
	["foam_amount", 0.0, 3.0],
	["foam_scale", 0.02, 20.0],
	["foam_speed", 0.0, 6.0],
	["edge_foam", 0.0, 3.0],
	["rapid_foam", 0.0, 3.0],
	["rim_width", 0.0, 10.0],
	["rim_ragged", 0.0, 1.0],
	"WHITECAPS (FOAM LYING ON OPEN WATER)",
	["whitecaps", 0.0, 2.0],
	["whitecap_size", 0.5, 300.0],
	["whitecap_clump", 0.0, 3.0],
	["whitecap_clump_size", 2.0, 400.0],
	"CREST FOAM (ON THE TOPS OF THE SWELL)",
	["crest_amount", 0.0, 2.0],
	["crest_size", 0.5, 300.0],
	["crest_ragged", 0.0, 3.0],
	"MOTION (THE SWELL)",
	["swell_height", 0.0, 2.0],
	["swell_length", 1.0, 120.0],
	["swell_speed", 0.0, 8.0],
	"SURFACE (THE RIPPLES AND THE LIGHT)",
	["roughness", 0.0, 1.0],
	["specular", 0.0, 1.0],
	["glint_pixels", 0.0, 32.0],
	["lines", 0.0, 1.0],
	["ripple_scale", 0.005, 20.0],
	["ripple_height", 0.0, 20.0],
	["ripple_choppy", 0.1, 12.0],
	["ripple_speed", 0.0, 20.0],
	"WAKE",
	["wake_life", 0.05, 4.0],
	["wake_spread", 0.0, 20.0],
	["wake_width", 0.0, 6.0],
	["wake_wiggle", 0.0, 3.0],
	["wake_wiggle_length", 0.2, 20.0],
	["wake_ragged", 0.0, 1.0],
	["wake_dashes", 0.0, 1.0],
	["wake_churn", 0.0, 1.0],
	["wake_echo", 0.0, 1.0],
	["wake_calm", 0.0, 1.0],
]

## A stage's preset taken up with COPY, to put down on another with PASTE.
static var _copied := {}

## The water in hand (set by main whenever the stage changes).
var track: Track:
	set(value):
		track = value
		_read()

var _wrap: Control
var _card: PanelContainer
var _body: Control
var _scroll: ScrollContainer
var _stage: Label
var _note: Label
var _hide: Button
var _names := {}
var _sliders := {}
var _values := {}
var _pickers := {}
var _reading := false
var _follow: Button
var _following := false
var _page: PanelContainer
var _page_text: Label
var _page_hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrap = Control.new()
	_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wrap)
	_card = PanelContainer.new()
	var frame := UI.card(Color(UI.PAPER, 0.94), UI.INK, 2, 6)
	frame.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", frame)
	_wrap.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	# the stage in hand, with arrows to look at another
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	top.add_child(_small("<", func() -> void: _step(-1), 44))
	_stage = UI.label("", 18, UI.INK, 0)
	_stage.add_theme_font_override("font", UI.serif())
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stage)
	top.add_child(_small(">", func() -> void: _step(1), 44))
	_follow = _small("STILL", _toggle_follow, 84)
	top.add_child(_follow)
	_hide = _small("HIDE", _toggle, 70)
	top.add_child(_hide)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	col.add_child(_body)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(500, 190)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	for row: Variant in ROWS:
		if row is String:
			var head := UI.label(row, 14, UI.RED, 0)
			head.add_theme_font_override("font", UI.italic())
			list.add_child(head)
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		list.add_child(line)
		var key: String = row[0]
		# (the name: a right click on it puts that one setting back)
		var name_label := UI.label(key.replace("_", " ").to_upper(), 13, UI.INK, 0)
		name_label.custom_minimum_size.x = 176
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
				_reset_one(key))
		line.add_child(name_label)
		_names[key] = name_label
		if row[1] == null:
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(200, 30)
			picker.edit_alpha = false
			picker.focus_mode = Control.FOCUS_NONE
			picker.color_changed.connect(func(c: Color) -> void: _change(key, c))
			line.add_child(picker)
			_pickers[key] = picker
			continue
		var slider := HSlider.new()
		slider.min_value = row[1]
		slider.max_value = row[2]
		slider.step = 0.001
		# (a slider that runs from very little to a great deal gives its low end as much room
		# as its high; and a number typed in may lie beyond either end)
		slider.exp_edit = float(row[1]) > 0.0 and float(row[2]) / float(row[1]) >= 40.0
		slider.allow_greater = true
		slider.allow_lesser = true
		# (the wheel moves the list, not whichever slider is under it)
		slider.scrollable = false
		slider.custom_minimum_size = Vector2(190, 30)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(v: float) -> void: _change(key, v))
		line.add_child(slider)
		_sliders[key] = slider
		# the number, which can be typed over
		var value := LineEdit.new()
		value.custom_minimum_size = Vector2(74, 28)
		value.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 13)
		value.select_all_on_focus = true
		value.add_theme_color_override("font_color", UI.NAVY)
		value.add_theme_stylebox_override("normal", UI.card(Color(1.0, 0.98, 0.92), Color(UI.INK, 0.35), 1, 4))
		value.add_theme_stylebox_override("focus", UI.card(Color(1.0, 1.0, 1.0), UI.RED, 2, 4))
		value.text_submitted.connect(func(_text: String) -> void: value.release_focus())
		value.focus_exited.connect(func() -> void: _typed(key))
		line.add_child(value)
		_values[key] = value
	_note = UI.label("", 12, UI.TEAL.darkened(0.5), 0)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(500, 18)
	_body.add_child(_note)
	if not Save.is_mobile():
		var keys := UI.label("VIEW   DRAG: LOOK ROUND   WHEEL, Q E: IN, OUT   W A S D: MOVE   R: BACK TO THE START\n"
				+ "PANEL   H: HIDE   F: FOLLOW   [ ]: STAGE   TYPE A NUMBER IN ITS BOX   RIGHT CLICK A NAME: PUT IT BACK", 11, UI.NAVY, 0)
		keys.custom_minimum_size = Vector2(500, 32)
		_body.add_child(keys)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_body.add_child(buttons)
	for b: Button in [_small("BACK", _back, 0), _small("RESET", _reset, 0), _small("COPY", _copy, 0),
			_small("PASTE", _paste, 0), _small("SAVE", _save, 0)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	_build_page()


# The page SAVE puts up, over everything: what has been changed on this stage.
func _build_page() -> void:
	_page = PanelContainer.new()
	var frame := UI.card(UI.PAPER, UI.INK, 2, 6)
	frame.set_content_margin_all(12)
	_page.add_theme_stylebox_override("panel", frame)
	_page.visible = false
	_wrap.add_child(_page)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_page.add_child(col)
	_page_text = UI.label("", 13, UI.INK, 0)
	_page_text.custom_minimum_size.x = 500
	col.add_child(_page_text)
	_page_hint = UI.label("", 12, UI.RED, 0)
	_page_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_page_hint.custom_minimum_size.x = 500
	col.add_child(_page_hint)
	col.add_child(_small("CLOSE", func() -> void: _page.visible = false, 0))


func _small(text: String, on_press: Callable, wide: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(wide, 40)
	b.add_theme_stylebox_override("normal", UI.card(Color(0.88, 0.83, 0.71), UI.INK, 2, 6))
	b.pressed.connect(func() -> void:
		Sfx.play("ui", 1.5, -6.0)
		on_press.call())
	return b


func set_stage(text: String) -> void:
	_stage.text = text


# Shows the panel or only its top row, to see the water.
func _toggle() -> void:
	_body.visible = not _body.visible
	_hide.text = "HIDE" if _body.visible else "SHOW"


func _toggle_follow() -> void:
	_following = not _following
	_follow.text = "FOLLOW" if _following else "STILL"
	follow_changed.emit(_following)


# (whatever has been set is written down before the stage is left)
func _step(dir: int) -> void:
	Track.write_presets()
	stage_stepped.emit(dir)


func _back() -> void:
	Track.write_presets()
	closed.emit()


# A click on the water leaves whichever box was being typed in, so that the keys go back to
# the view.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().gui_release_focus()


# The keys of the panel (those of the view are the camera's: see chase_camera.gd).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_H:
			_toggle()
		KEY_F:
			_toggle_follow()
		KEY_BRACKETLEFT:
			_step(-1)
		KEY_BRACKETRIGHT:
			_step(1)


# A number as short as it can be written.
func _text(v: float) -> String:
	return String.num(v, 3)


# Fills the sliders from the water as it is.
func _read() -> void:
	if track == null or track.mat_water == null or _sliders.is_empty():
		return
	_reading = true
	for key: String in _sliders:
		var v: float = _now(key)
		(_sliders[key] as HSlider).value = v
		(_values[key] as LineEdit).text = _text(v)
	for key: String in _pickers:
		(_pickers[key] as ColorPickerButton).color = _now(key)
	_reading = false
	_mark()


# Shows which settings are this stage's own doing (in red, with a star), and how many.
func _mark() -> void:
	var preset := track.water_preset()
	for key: String in _names:
		var label := _names[key] as Label
		var changed := preset.has(key)
		label.text = key.replace("_", " ").to_upper() + (" *" if changed else "")
		label.add_theme_color_override("font_color", UI.RED if changed else UI.INK)
	_note.text = "%d SET BY HAND (*) ON THIS STAGE, AND USED ON THIS STAGE ONLY." % preset.size()


func _now(key: String) -> Variant:
	if key == "wake_life":
		return track.wake_life
	var mat := track.mat_water
	var v: Variant = mat.get_shader_parameter(key)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), key)
	return v


func _change(key: String, value: Variant) -> void:
	if _reading or track == null:
		return
	track.water_preset()[key] = value
	# (through the stage, so that what floats on the swell keeps to the same swell)
	track.apply_water()
	if _values.has(key):
		(_values[key] as LineEdit).text = _text(float(value))
	_mark()


# A number typed into a box: any number, whatever the ends of its slider.
func _typed(key: String) -> void:
	var box := _values[key] as LineEdit
	if not box.text.is_valid_float():
		box.text = _text(float(_now(key)))
		return
	var v := box.text.to_float()
	if is_equal_approx(v, float(_now(key))):
		return
	# (the slider goes there too, which sets it)
	(_sliders[key] as HSlider).value = v


# One setting back to the stage's own.
func _reset_one(key: String) -> void:
	if track == null:
		return
	track.water_preset().erase(key)
	track.apply_water()
	_read()


# All of them back to the stage's own.
func _reset() -> void:
	track.water_preset().clear()
	track.apply_water()
	_read()


func _copy() -> void:
	_copied = track.water_preset().duplicate()
	_note.text = "%d SETTINGS TAKEN UP: GO TO ANOTHER STAGE AND PASTE." % _copied.size()


# What was taken up from another stage, in place of whatever this one had.
func _paste() -> void:
	var preset := track.water_preset()
	preset.clear()
	preset.merge(_copied)
	track.apply_water()
	_read()


# Every value as it stands, as text: the changed ones first and marked, then the rest.
func _report(all: bool) -> String:
	var preset := track.water_preset()
	var changed := PackedStringArray()
	var same := PackedStringArray()
	for row: Variant in ROWS:
		if row is String:
			continue
		var key: String = row[0]
		var v: Variant = _now(key)
		var line := "%s = (%.2f, %.2f, %.2f)" % [key, v.r, v.g, v.b] if v is Color else "%s = %s" % [key, _text(float(v))]
		if preset.has(key):
			changed.append(line)
		else:
			same.append(line)
	var text := "SALMON RUN 2 WATER, ON %s\nSET BY HAND:\n%s" % [_stage.text, "\n".join(changed) if not changed.is_empty() else "(nothing)"]
	return text + "\nTHE STAGE'S OWN:\n" + "\n".join(same) if all else text


# SAVE: writes every stage's preset into the project, copies this stage's values as text, and
# puts up a page of what has been changed here.
func _save() -> void:
	var kept := Track.write_presets()
	DisplayServer.clipboard_set(_report(true))
	_page_text.text = _report(false)
	_page_hint.text = ("SAVED IN THE PROJECT (MATERIALS/WATER_PRESETS.CFG), AND EVERY VALUE COPIED AS TEXT." if kept
			else "NOT SAVED: ONLY A GAME RUN FROM ITS PROJECT CAN. EVERY VALUE HAS BEEN COPIED AS TEXT.")
	_page.visible = true


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var area := size
	var tall := area.y > area.x
	# on a desktop the list runs the whole height of the window; on a phone it is a short one
	# across the bottom of the screen, as wide as the phone allows
	var docked := not tall and not Save.is_mobile() and _body.visible
	if not _body.visible:
		pass
	elif docked:
		var rest := _card.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
		_scroll.custom_minimum_size.y = maxf(190.0, area.y - 40.0 - rest)
	else:
		_scroll.custom_minimum_size.y = 190.0
	var card := _card.get_combined_minimum_size()
	_card.size = card
	var k := clampf((area.x - 40.0) / card.x, 1.0, 2.6) if tall else 1.0
	_wrap.scale = Vector2(k, k)
	_wrap.position = Vector2((area.x - card.x * k) * 0.5 if tall else 20.0, area.y - card.y * k - (40.0 if tall else 20.0))
	# (the page of saved values stands over the panel, its foot level with the panel's)
	_page.size = _page.get_combined_minimum_size()
	_page.position = Vector2(0.0, card.y - _page.size.y)
