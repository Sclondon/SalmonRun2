extends CanvasLayer
## In-race heads-up display: score, timer, trick callouts, combo, boost, beat indicator.

const UI := preload("res://scripts/ui/ui_kit.gd")

var root: Control
var _score: Label
var _time: Label
var _best: Label
var _trick: Label
var _trick_pts: Label
var _combo: Label
var _combo_bar: ProgressBar
var _popup: Label
var _banner: Label
var _platinum: ShaderMaterial
var _count: Label
var _speed: Label
var _boost_label: Label
var _boost_box: Control
var _touch_mode := false
var _boost: ProgressBar
var _progress: ProgressBar
var _objective: Label
var _beat_dots: Array[ColorRect] = []
var _trick_t := 0.0
var _popup_t := 0.0
var _count_t := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var tl := VBoxContainer.new()
	tl.position = Vector2(28, 18)
	root.add_child(tl)
	tl.add_child(UI.label("SCORE", 22, UI.TEAL, 6))
	_score = UI.label("0", 52, Color.WHITE)
	tl.add_child(_score)

	var tr := VBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-260, 18)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(tr)
	_time = UI.label("0:00.00", 44, Color.WHITE)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time.custom_minimum_size.x = 232
	tr.add_child(_time)
	_best = UI.label("", 20, UI.GOLD, 6)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best.custom_minimum_size.x = 232
	tr.add_child(_best)

	_progress = UI.bar(UI.SALMON, Vector2(420, 12))
	_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_progress.position = Vector2(-210, 26)
	root.add_child(_progress)

	_objective = _centered(UI.label("", 22, Color.WHITE, 6))
	_objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_objective.position = Vector2(-400, 44)
	_objective.custom_minimum_size = Vector2(800, 0)
	root.add_child(_objective)

	var mid := VBoxContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mid.position = Vector2(-500, 110)
	mid.custom_minimum_size = Vector2(1000, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(mid)
	_trick = _centered(UI.label("", 44, UI.GOLD, 12))
	mid.add_child(_trick)
	_trick_pts = _centered(UI.label("", 30, Color.WHITE))
	mid.add_child(_trick_pts)
	_combo = _centered(UI.label("", 30, UI.OCHRE))
	mid.add_child(_combo)
	var cb_row := CenterContainer.new()
	mid.add_child(cb_row)
	_combo_bar = UI.bar(UI.OCHRE, Vector2(240, 10))
	cb_row.add_child(_combo_bar)

	_popup = _centered(UI.label("", 64, UI.CORAL, 14))
	_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_popup.position = Vector2(-500, 30)
	_popup.custom_minimum_size = Vector2(1000, 80)
	root.add_child(_popup)
	# the name of a stage swum on to: it comes down from above the top of the screen
	_banner = _centered(UI.label("", 54, UI.TEAL, 14))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.custom_minimum_size = Vector2(1000, 70)
	_banner.position = Vector2(-500, -120)
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	_count = _centered(UI.label("", 150, UI.GOLD, 20))
	_count.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_count.position = Vector2(-500, -110)
	_count.custom_minimum_size = Vector2(1000, 180)
	root.add_child(_count)

	var bl := VBoxContainer.new()
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(30, -86)
	root.add_child(bl)
	_boost_box = bl
	_boost_label = UI.label("BOOST  [SHIFT]", 20, UI.TEAL, 6)
	bl.add_child(_boost_label)
	_boost = UI.bar(UI.TEAL, Vector2(300, 22))
	bl.add_child(_boost)

	_speed = UI.label("0 KM/H", 40, Color.WHITE)
	_speed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed.position = Vector2(-260, -76)
	_speed.custom_minimum_size.x = 232
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_speed)

	var beats := HBoxContainer.new()
	beats.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	beats.position = Vector2(-82, -48)
	beats.add_theme_constant_override("separation", 12)
	root.add_child(beats)
	for i in 4:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(32, 16)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		beats.add_child(d)
		_beat_dots.append(d)


## On touch screens the thumbs cover the bottom corners, so the boost meter moves up under
## the score and the speed readout is hidden.
func set_touch_mode(on: bool) -> void:
	if on == _touch_mode:
		return
	_touch_mode = on
	_boost_label.text = "BOOST" if on else "BOOST  [SHIFT]"
	_speed.visible = not on
	if on:
		_boost_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 30)
		_boost_box.offset_top += 110.0
		_boost_box.offset_bottom += 110.0
	else:
		_boost_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 30)


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## The stage's goal, shown under the progress bar; it turns green once it is met.
func set_objective(text: String, done: bool) -> void:
	_objective.text = text
	_objective.add_theme_color_override("font_color", UI.GOLD if done else Color.WHITE)


func set_best(best: int) -> void:
	_best.text = "BEST %s" % fmt(best)


func show_trick(trick_name: String, points: int, flow: int, grade: int) -> void:
	_trick.text = trick_name.to_upper()
	_trick_pts.text = "+%s" % fmt(points) + ("   (x%d FLOW)" % flow if flow > 1 else "")
	_trick.add_theme_color_override("font_color", GRADE_COLORS[grade])
	_trick_t = 2.4
	_trick.modulate.a = 1.0
	_trick_pts.modulate.a = 1.0
	_trick.pivot_offset = _trick.size * 0.5
	_trick.scale = Vector2.ONE * 1.3
	create_tween().tween_property(_trick, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


## The colour of each grade of timing, worst first (see Score.GRADES): from a dim blue-purple
## up through blue and green to gold for EXCELLENT. PERFECT! is polished platinum.
const GRADE_COLORS := [
	Color(0.44, 0.38, 0.72), Color(0.52, 0.44, 0.88), Color(0.5, 0.54, 0.97), Color(0.42, 0.68, 0.98),
	Color(0.36, 0.82, 0.86), Color(0.52, 0.88, 0.5), Color(0.98, 0.62, 0.3), Color(0.98, 0.8, 0.25),
	Color(0.92, 0.94, 0.98),
]


## Calls out how well a trick was timed.
func show_grade(grade: int, text: String) -> void:
	popup(text, GRADE_COLORS[grade], 0.9, grade == GRADE_COLORS.size() - 1)


func popup(text: String, col: Color, dur := 1.2, platinum := false) -> void:
	_popup.text = text
	_popup.add_theme_color_override("font_color", col)
	# (the best there is gleams like metal)
	if platinum and _platinum == null:
		_platinum = ShaderMaterial.new()
		_platinum.shader = preload("res://shaders/platinum.gdshader")
	_popup.material = _platinum if platinum else null
	if platinum:
		var box := _popup.get_global_rect()
		var screen := get_viewport().get_visible_rect().size
		_platinum.set_shader_parameter("middle", (box.position.y + box.size.y * 0.5) / screen.y)
		_platinum.set_shader_parameter("tall", 70.0 / screen.y)
	_popup_t = dur
	_popup.modulate.a = 1.0
	_popup.pivot_offset = _popup.size * 0.5
	_popup.scale = Vector2.ONE * 1.6
	create_tween().tween_property(_popup, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func countdown(text: String) -> void:
	_count.text = text
	_count_t = 0.7
	_count.modulate.a = 1.0
	_count.pivot_offset = _count.size * 0.5
	_count.scale = Vector2.ONE * 1.5
	create_tween().tween_property(_count, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func set_stats(score: int, time: float, progress: float, boost: float, kmh: float) -> void:
	_score.text = fmt(score)
	_time.text = fmt_time(time)
	_progress.value = progress
	_boost.value = boost / 100.0
	_speed.text = "%d KM/H" % int(kmh)


func set_flow(flow: int, frac: float) -> void:
	if flow <= 1:
		_combo.text = ""
		_combo_bar.visible = false
		return
	_combo.text = "FLOW  x%d" % flow
	_combo_bar.visible = true
	_combo_bar.value = frac


func _process(delta: float) -> void:
	_trick_t -= delta
	if _trick_t < 0.6:
		_trick.modulate.a = clampf(_trick_t / 0.6, 0.0, 1.0)
		_trick_pts.modulate.a = _trick.modulate.a
	_popup_t -= delta
	if _popup_t < 0.4:
		_popup.modulate.a = clampf(_popup_t / 0.4, 0.0, 1.0)
	_count_t -= delta
	if _count_t < 0.3:
		_count.modulate.a = clampf(_count_t / 0.3, 0.0, 1.0)
	var bf := Music.beat_float()
	var cur := int(floorf(bf)) % 4 if bf >= 0.0 else -1
	var pulse := Music.beat_pulse()
	for i in 4:
		var on := i == cur
		var base := UI.CORAL if i == 0 else UI.TEAL
		_beat_dots[i].color = base.lerp(Color.WHITE, pulse * 0.6) if on else Color(base, 0.25)
		_beat_dots[i].scale = Vector2.ONE * (1.0 + (pulse * 0.35 if on else 0.0))


static func fmt(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var sec := fmod(t, 60.0)
	return "%d:%05.2f" % [m, sec]


## The name of the stage just swum on to: let down from above the top of the screen, held
## a while, and drawn back up.
func banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.position.y = -120.0
	var drop := create_tween()
	drop.tween_property(_banner, "position:y", 96.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_interval(2.2)
	drop.tween_property(_banner, "position:y", -120.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	drop.tween_property(_banner, "modulate:a", 0.0, 0.05)
