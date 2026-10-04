extends Control
## The title-screen logo: chunky extruded letters that bob and hop on the beat, a giant "2"
## on a spinning burst, and a wave running underneath.

const UI := preload("res://scripts/ui/ui_kit.gd")

const SIZE := 118
const BIG := 270
const DEPTH := 9
const SLANT := 0.2
const EXTRUDE := Color(0.36, 0.05, 0.42)

var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(860, 262)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var pulse := Music.beat_pulse()
	var font := UI.font()
	var w := _word(font, "SALMON", Vector2(8, 104), 0, UI.SALMON, UI.ORANGE, pulse)
	_word(font, "RUN", Vector2(64, 204), 6, UI.CYAN, UI.LIME, pulse)
	_two(font, Vector2(w + 120.0, 118.0), pulse)
	_wave(Vector2(0, 238), w + 250.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Draws a word one letter at a time and returns where it ended (x).
func _word(font: Font, text: String, at: Vector2, first: int, c0: Color, c1: Color, pulse: float) -> float:
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var k := first + i
		var hop := sin(_t * 2.6 - k * 0.6) * 5.0 - pulse * (9.0 if k % 2 == 0 else 3.0)
		var col := c0.lerp(c1, float(i) / maxf(text.length() - 1, 1.0)).lerp(Color.WHITE, pulse * 0.35)
		# sheared so the letters lean forward
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-SLANT, 1), Vector2(x, at.y + hop)))
		_block(font, ch, SIZE, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 4.0
	return x


## One glyph with a dark outline and a solid extrusion down and to the right.
func _block(font: Font, text: String, font_size: int, col: Color) -> void:
	for d in range(DEPTH, 0, -1):
		draw_string_outline(font, Vector2(d, d), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, UI.INK)
	draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, UI.INK)
	for d in range(DEPTH, 0, -1):
		draw_string(font, Vector2(d, d), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, EXTRUDE)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _two(font: Font, center: Vector2, pulse: float) -> void:
	# spinning burst behind it
	var pts := PackedVector2Array()
	var ink := PackedVector2Array()
	var spikes := 14
	for i in spikes * 2:
		var a := _t * 0.5 + i * PI / spikes
		var r := (132.0 if i % 2 == 0 else 98.0) * (1.0 + pulse * 0.12)
		pts.append(Vector2(cos(a), sin(a)) * r)
		ink.append(Vector2(cos(a), sin(a)) * (r + 9.0))
	draw_set_transform_matrix(Transform2D(0.0, center))
	draw_colored_polygon(ink, UI.INK)
	draw_colored_polygon(pts, UI.PINK)
	# the 2 itself, tilted and thumping on the beat
	var sc := 1.0 + pulse * 0.1
	var sz := font.get_string_size("2", HORIZONTAL_ALIGNMENT_LEFT, -1, BIG)
	var tf := Transform2D(-0.14 + sin(_t * 1.3) * 0.04, Vector2(sc, sc), 0.0, center)
	draw_set_transform_matrix(tf * Transform2D(0.0, Vector2(-sz.x * 0.5 - 4.0, BIG * 0.34)))
	_block(font, "2", BIG, UI.LIME.lerp(Color.WHITE, pulse * 0.4))


func _wave(at: Vector2, width: float) -> void:
	draw_set_transform_matrix(Transform2D(0.0, at))
	for layer in 2:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= width:
			pts.append(Vector2(x, sin(x * 0.045 - _t * (4.0 - layer * 1.5) + layer * 1.7) * 6.0 + layer * 11.0))
			x += 8.0
		draw_polyline(pts, UI.INK, 12.0)
		draw_polyline(pts, UI.CYAN if layer == 0 else Color.WHITE, 6.0)
