extends RefCounted
## Shared fonts, colours and widget factories for the chunky SSX-style UI.

const LIME := Color(0.72, 1.0, 0.22)
const PINK := Color(1.0, 0.3, 0.62)
const CYAN := Color(0.25, 1.0, 0.9)
const ORANGE := Color(1.0, 0.62, 0.12)
const SALMON := Color(1.0, 0.52, 0.42)
const RED := Color(1.0, 0.22, 0.2)
const INK := Color(0.04, 0.02, 0.08)

static var _font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		# Bundled so the web build looks the same as desktop (browsers have no Impact)
		var f := FontVariation.new()
		f.base_font = load("res://fonts/PixelifySans.ttf")
		f.variation_embolden = 0.5
		_font = f
	return _font


static func label(text: String, size: int, col := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func flat(bg: Color, border := Color.TRANSPARENT, border_w := 0, skew := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.skew = Vector2(skew, 0.0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func bar(fill: Color, min_size := Vector2(260, 18)) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.min_value = 0.0
	b.max_value = 1.0
	b.add_theme_stylebox_override("background", flat(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.5), 2, 0.3))
	b.add_theme_stylebox_override("fill", flat(fill, Color.TRANSPARENT, 0, 0.3))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 30
	t.set_stylebox("normal", "Button", flat(Color(0.03, 0.12, 0.12, 0.85), CYAN, 3, 0.35))
	t.set_stylebox("hover", "Button", flat(Color(0.3, 0.05, 0.2, 0.95), PINK, 3, 0.35))
	t.set_stylebox("focus", "Button", flat(Color(0.3, 0.05, 0.2, 0.95), LIME, 4, 0.35))
	t.set_stylebox("pressed", "Button", flat(PINK, Color.WHITE, 3, 0.35))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", LIME)
	t.set_color("font_focus_color", "Button", LIME)
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 8)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)
	t.set_stylebox("panel", "PanelContainer", flat(Color(0.02, 0.05, 0.08, 0.88), PINK, 3, 0.0))
	_theme = t
	return t


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		on_press.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui", 1.5, -10.0))
	return b
