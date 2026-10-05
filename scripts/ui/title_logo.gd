extends Control
## The title: set like the cover of a 1990s school science book. A bookish serif name, the
## numeral on a gold disc with a couple of plain geometric shapes behind it, the species'
## Latin name in italics and a fine rule.

const UI := preload("res://scripts/ui/ui_kit.gd")

const SIZE := 104

var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(900, 214)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var pulse := Music.beat_pulse()
	var sans := UI.font()
	var serif := UI.serif()
	# a strapline over a fine rule, the way a textbook series is credited
	_text(sans, Vector2(4, 22), "AN INTERACTIVE JOURNEY   ·   THE LIFE CYCLE OF THE PACIFIC SALMON", 19, UI.PAPER, 6)
	draw_rect(Rect2(4, 34, 640, 3), UI.INK)
	draw_rect(Rect2(4, 34, 640, 2), UI.GOLD)
	# the name
	var name_at := Vector2(0, 138)
	var w := serif.get_string_size("Salmon Run", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	draw_string_outline(serif, name_at + Vector2(5, 6), "Salmon Run", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 14, Color(UI.INK, 0.55))
	_text(serif, name_at, "Salmon Run", SIZE, UI.PAPER, 14)
	# the numeral, on a gold disc with a triangle and a square tucked behind it
	var c := Vector2(w + 96.0, 96.0 + sin(_t * 1.4) * 3.0)
	var r := 62.0 * (1.0 + pulse * 0.03)
	_shape(PackedVector2Array([c + Vector2(-78, 54), c + Vector2(-6, -86), c + Vector2(50, 54)]), UI.CORAL)
	_shape(PackedVector2Array([c + Vector2(22, -6), c + Vector2(92, -6), c + Vector2(92, 64), c + Vector2(22, 64)]), UI.TEAL)
	draw_circle(c, r + 4.0, UI.INK)
	draw_circle(c, r, UI.GOLD)
	var two := serif.get_string_size("2", HORIZONTAL_ALIGNMENT_LEFT, -1, 108)
	draw_string(serif, c + Vector2(-two.x * 0.5, 38.0), "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 108, UI.INK)
	# the species, as a caption
	_text(UI.italic(), Vector2(6, 184), "Oncorhynchus nerka", 30, UI.TEAL, 8)
	_text(sans, Vector2(310, 182), "THE SOCKEYE, HEADING HOME", 19, UI.PAPER, 6)


func _text(font: Font, at: Vector2, text: String, font_size: int, col: Color, outline: int) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, UI.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## A flat shape with a navy edge.
func _shape(points: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(points, col)
	var edge := points.duplicate()
	edge.append(points[0])
	draw_polyline(edge, UI.INK, 4.0)
