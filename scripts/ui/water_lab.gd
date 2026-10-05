extends Control
## The water lab: the salmon swims a stage on its own while a panel of sliders changes the
## water shader as you watch. What is set here is kept (in the save) and used in play too,
## on every stage, until RESET. SAVE hands every value over as text (see _save).

signal closed
## Asks for another stage to look at (-1 or 1).
signal stage_stepped(dir: int)
## Asks for the camera to go with the salmon (true) or to stand still over the water.
signal follow_changed(on: bool)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Track := preload("res://scripts/world/track.gd")
const Wake := preload("res://scripts/fx/wake.gd")

## The settings, in the order shown: [uniform, label, least, most]. A null least marks a
## colour. Headings are a lone string.
const ROWS := [
	"COLOUR",
	["deep", "DEEP", null, null],
	["shallow", "SHALLOW", null, null],
	["foam_color", "FOAM", null, null],
	["depth_range", "DEPTH RANGE (M)", 1.0, 60.0],
	["alpha_shallow", "CLEAR WHEN SHALLOW", 0.0, 1.0],
	["alpha_deep", "SOLID WHEN DEEP", 0.0, 1.0],
	["ripple", "COLOUR RIPPLE", 0.0, 1.0],
	"SURFACE",
	["roughness", "ROUGHNESS", 0.0, 1.0],
	["specular", "SPECULAR", 0.0, 1.0],
	["wave_height", "WAVE HEIGHT", 0.0, 2.0],
	["wave_scale", "WAVE FINENESS", 0.1, 3.0],
	["wave_choppy", "WAVE PEAKS", 0.5, 5.0],
	["wave_speed", "WAVE SPEED", 0.0, 3.0],
	["swell", "SWELL", 0.0, 6.0],
	["lines", "PALE LINES", 0.0, 1.0],
	["sparkle", "BEAT SHIMMER", 0.0, 2.0],
	"FOAM",
	["whitecaps", "WHITECAPS", 0.0, 1.0],
	["foam_amount", "DRIFTING FOAM", 0.0, 1.0],
	["foam_scale", "FOAM FINENESS", 0.2, 4.0],
	["edge_foam", "BANK FOAM", 0.0, 1.0],
	["rim_width", "RIM WIDTH (M)", 0.0, 2.0],
	["rim_ragged", "RIM RAGGED", 0.0, 1.0],
	"WAKE",
	["wake_life", "WAKE LENGTH (S)", 0.1, 2.0],
	["wake_spread", "WAKE SPREAD", 0.0, 5.0],
	["wake_width", "WAKE WIDTH (M)", 0.05, 1.5],
]

## The water in hand (set by main whenever the stage changes).
var track: Track:
	set(value):
		track = value
		_read()

var _wrap: Control
var _card: PanelContainer
var _body: Control
var _stage: Label
var _note: Label
var _hide: Button
var _sliders := {}
var _values := {}
var _pickers := {}
var _reading := false
var _follow: Button
var _following := false
var _page: PanelContainer
var _page_text: Label


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
	top.add_child(_small("<", func() -> void: stage_stepped.emit(-1), 44))
	_stage = UI.label("", 18, UI.INK, 0)
	_stage.add_theme_font_override("font", UI.serif())
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stage)
	top.add_child(_small(">", func() -> void: stage_stepped.emit(1), 44))
	_follow = _small("STILL", func() -> void:
		_following = not _following
		_follow.text = "FOLLOW" if _following else "STILL"
		follow_changed.emit(_following), 84)
	top.add_child(_follow)
	_hide = _small("HIDE", _toggle, 70)
	top.add_child(_hide)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	col.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for row: Variant in ROWS:
		if row is String:
			var head := UI.label(row, 14, UI.RED, 0)
			head.add_theme_font_override("font", UI.italic())
			list.add_child(head)
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		list.add_child(line)
		var name_label := UI.label(row[1], 13, UI.INK, 0)
		name_label.custom_minimum_size.x = 170
		line.add_child(name_label)
		var key: String = row[0]
		if row[2] == null:
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(200, 30)
			picker.edit_alpha = false
			picker.focus_mode = Control.FOCUS_NONE
			picker.color_changed.connect(func(c: Color) -> void: _change(key, c))
			line.add_child(picker)
			_pickers[key] = picker
			continue
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = (float(row[3]) - float(row[2])) / 200.0
		slider.custom_minimum_size = Vector2(190, 30)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(v: float) -> void: _change(key, v))
		line.add_child(slider)
		_sliders[key] = slider
		var value := UI.label("", 13, UI.NAVY, 0)
		value.custom_minimum_size.x = 46
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		_values[key] = value
	_note = UI.label("", 12, UI.TEAL.darkened(0.5), 0)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(440, 18)
	_body.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_body.add_child(buttons)
	for b: Button in [_small("BACK", func() -> void: closed.emit(), 0), _small("RESET", _reset, 0), _small("SAVE", _save, 0)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	_build_page()


# The page of values SAVE puts up, over everything, to read or take a picture of.
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
	_page_text.custom_minimum_size.x = 440
	col.add_child(_page_text)
	var hint := UI.label("SAVED. SENT TO SHARE OR DOWNLOAD, AND COPIED; OR TAKE A PICTURE OF THIS PAGE.", 12, UI.RED, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size.x = 440
	col.add_child(hint)
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


# Fills the sliders from the water as it is.
func _read() -> void:
	if track == null or track.mat_water == null or _sliders.is_empty():
		return
	_reading = true
	for key: String in _sliders:
		var v: float = _now(key)
		(_sliders[key] as HSlider).value = v
		(_values[key] as Label).text = "%.2f" % v
	for key: String in _pickers:
		(_pickers[key] as ColorPickerButton).color = _now(key)
	_reading = false
	_note.text = "%d CHANGED FROM THE STAGE'S OWN. KEPT, AND USED ON EVERY STAGE, UNTIL RESET." % Track.water_overrides.size()


func _now(key: String) -> Variant:
	if key == "wake_life":
		return Wake.life
	var mat := track.mat_water
	var v: Variant = mat.get_shader_parameter(key)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), key)
	return v


func _change(key: String, value: Variant) -> void:
	if _reading or track == null:
		return
	Track.water_overrides[key] = value
	if key == "wake_life":
		Wake.life = value
	else:
		track.mat_water.set_shader_parameter(key, value)
	if _values.has(key):
		(_values[key] as Label).text = "%.2f" % float(value)
	_note.text = "%d CHANGED FROM THE STAGE'S OWN. KEPT, AND USED ON EVERY STAGE, UNTIL RESET." % Track.water_overrides.size()
	Save.water = Track.water_overrides


# Back to each stage's own water.
func _reset() -> void:
	Track.water_overrides.clear()
	Wake.life = Wake.LIFE
	Save.water = Track.water_overrides
	Save.store()
	track.apply_water()
	_read()


# Every value as it stands, as text: the changed ones first and marked, then the rest.
func _report() -> String:
	var changed := PackedStringArray()
	var same := PackedStringArray()
	for row: Variant in ROWS:
		if row is String:
			continue
		var key: String = row[0]
		var v: Variant = _now(key)
		var line := "%s = (%.2f, %.2f, %.2f)" % [key, v.r, v.g, v.b] if v is Color else "%s = %.2f" % [key, float(v)]
		if Track.water_overrides.has(key):
			changed.append(line)
		else:
			same.append(line)
	return "SALMON RUN 2 WATER, ON %s\nCHANGED:\n%s\nUNCHANGED:\n%s" % [_stage.text,
			"\n".join(changed) if not changed.is_empty() else "(nothing)", "\n".join(same)]


# SAVE: keeps the values, and hands them over as text every way there is, so that one of them
# works wherever this is running: the share sheet of a phone (or a downloaded text file), the
# clipboard, and a page of them on the screen to take a picture of.
func _save() -> void:
	Save.water = Track.water_overrides
	Save.store()
	var text := _report()
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function(text) {
				var file = function() {
					var a = document.createElement('a');
					a.href = URL.createObjectURL(new Blob([text], {type: 'text/plain'}));
					a.download = 'salmon-water.txt';
					document.body.appendChild(a); a.click(); a.remove();
				};
				if (navigator.share) { navigator.share({title: 'Salmon Run 2 water', text: text}).catch(file); } else { file(); }
			})(%s);
		""" % JSON.stringify(text), true)
	_page_text.text = text
	_page.visible = true


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	# across the bottom of the screen, as wide as a phone allows
	var area := size
	var card := _card.get_combined_minimum_size()
	_card.size = card
	var tall := area.y > area.x
	var k := clampf((area.x - 40.0) / card.x, 1.0, 2.6) if tall else 1.0
	_wrap.scale = Vector2(k, k)
	_wrap.position = Vector2((area.x - card.x * k) * 0.5 if tall else 20.0, area.y - card.y * k - (40.0 if tall else 20.0))
	# (the page of saved values stands over the panel, its foot level with the panel's)
	_page.size = _page.get_combined_minimum_size()
	_page.position = Vector2(0.0, card.y - _page.size.y)
