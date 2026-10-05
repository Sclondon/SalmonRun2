extends RefCounted
## Shared fonts, colours and widget factories. The look is the 1990s educational one
## ("Utopian Scholastic": encyclopedia CD-ROMs and school science books): a bookish serif for
## headings, a clean geometric sans for everything else, deep navy plates with cream paper
## buttons, and a few confident primary colours.

const GOLD := Color(0.98, 0.80, 0.25)
const TEAL := Color(0.38, 0.82, 0.80)
const CORAL := Color(0.96, 0.45, 0.36)
const OCHRE := Color(0.94, 0.64, 0.26)
const SALMON := Color(0.97, 0.55, 0.44)
const RED := Color(0.86, 0.24, 0.2)
## Outlines and text on paper
const INK := Color(0.06, 0.09, 0.2)
## Plates (panels) and the paper the buttons are cut from
const NAVY := Color(0.08, 0.13, 0.29)
const PAPER := Color(0.96, 0.93, 0.85)

static var _font: Font
static var _serif: Font
static var _italic: Font
static var _theme: Theme


## The everyday face: a geometric sans (Jost), a little heavier than regular so it holds up
## over the game. Bundled so the web build looks the same as desktop.
static func font() -> Font:
	if _font == null:
		_font = _weighted("res://fonts/Jost.ttf", 600)
	return _font


## The heading face: a bold bookish serif (Libre Baskerville).
static func serif() -> Font:
	if _serif == null:
		_serif = _weighted("res://fonts/LibreBaskerville.ttf", 700)
	return _serif


static func italic() -> Font:
	if _italic == null:
		_italic = _weighted("res://fonts/LibreBaskerville-Italic.ttf", 600)
	return _italic


static func _weighted(path: String, weight: int) -> Font:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {"wght": weight}
	return f


## Text that sits over the game or on a navy plate. Big text is set in the serif.
static func label(text: String, size: int, col := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", serif() if size >= 36 else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func flat(bg: Color, border := Color.TRANSPARENT, border_w := 0, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## A flat style with a soft shadow under it, like a card lying on the page.
static func card(bg: Color, border: Color, border_w: int, radius := 6) -> StyleBoxFlat:
	var sb := flat(bg, border, border_w, radius)
	sb.shadow_color = Color(0.0, 0.02, 0.08, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func bar(fill: Color, min_size := Vector2(260, 18)) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.min_value = 0.0
	b.max_value = 1.0
	b.add_theme_stylebox_override("background", flat(Color(NAVY, 0.7), PAPER, 2, 5))
	b.add_theme_stylebox_override("fill", flat(fill, Color.TRANSPARENT, 0, 4))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 28
	# buttons are cream paper with navy lettering; the one in hand turns gold
	t.set_stylebox("normal", "Button", card(PAPER, INK, 2, 8))
	t.set_stylebox("hover", "Button", card(Color(1.0, 0.97, 0.88), TEAL.darkened(0.3), 3, 8))
	t.set_stylebox("focus", "Button", card(GOLD, INK, 3, 8))
	t.set_stylebox("pressed", "Button", card(OCHRE, INK, 3, 8))
	t.set_stylebox("disabled", "Button", card(Color(PAPER, 0.5), Color(INK, 0.5), 2, 8))
	for colour: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(colour, "Button", INK)
	t.set_constant("outline_size", "Button", 0)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)
	# plates: deep navy with a cream rule round them
	t.set_stylebox("panel", "PanelContainer", card(Color(NAVY, 0.94), PAPER, 2, 10))
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
