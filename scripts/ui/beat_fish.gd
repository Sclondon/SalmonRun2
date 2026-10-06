extends Control
## The beat keeper: a row of four little pixel salmon along the bottom of the screen, one for
## each beat of the bar. The one whose beat it is leaps clear of the water, nose up on the way
## and nose down coming in, and is back in it as the next one goes. The first of the four,
## the downbeat, is a red spawner; the others are silver.
##
## (With `icon` set it is one salmon by itself, still: the sign beside the count of how many
## are swimming with you.)

const UI := preload("res://scripts/ui/ui_kit.gd")

## The salmon, a pixel to a letter, facing right: b back, s side, w belly, h head, e eye,
## f fin and tail.
const FISH := [
	"............bbbb............",
	"ff.........bbbbbbb..........",
	"fff.....bbbbbbbbbbbbbb......",
	".fff..bbbssssssssssssbbhh...",
	"..ffffsssssssssssssssshhhh..",
	"..ffffssssssssssssssshhhehh.",
	".fff..sswwwwwwwwwwwwsshhhhh.",
	"fff.....wwwwwwwwwwwwwwhhh...",
	"ff........wwwffwwwwff.......",
	"...........ff.....ff........",
]
## How big a pixel of it is, how far apart the four are, and how high the leap is.
const PIXEL := 3.0
const APART := 150.0
const LEAP := 56.0

## One salmon, still, as a sign (see above).
var icon := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(92.0, 46.0) if icon else Vector2(APART * 4.0, 150.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(_delta: float) -> void:
	if is_visible_in_tree() and not icon:
		queue_redraw()


# Draws one salmon with its middle at `middle`, turned by `tilt`.
func _fish(middle: Vector2, tilt: float, red: bool, dim: float, pixel: float) -> void:
	var wide := float(str(FISH[0]).length()) * pixel
	var tall := FISH.size() * pixel
	var inks := {
		"b": Color(0.62, 0.1, 0.1) if red else Color(0.16, 0.3, 0.44),
		"s": Color(0.94, 0.26, 0.2) if red else Color(0.72, 0.8, 0.88),
		"w": Color(1.0, 0.72, 0.6) if red else Color(0.96, 0.98, 1.0),
		"h": Color(0.36, 0.56, 0.24) if red else Color(0.3, 0.44, 0.56),
		"e": Color(0.05, 0.05, 0.08),
		"f": Color(0.7, 0.14, 0.12) if red else Color(0.36, 0.48, 0.6),
	}
	draw_set_transform(middle, tilt, Vector2.ONE)
	for row in FISH.size():
		var line: String = FISH[row]
		for col in line.length():
			var ink := line[col]
			if ink == ".":
				continue
			draw_rect(Rect2(col * pixel - wide * 0.5, row * pixel - tall * 0.5, pixel, pixel), Color(inks[ink], dim))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if icon:
		_sign(size * 0.5, 78.0)
		return
	var beat := Music.beat_float()
	var now := int(floorf(beat)) % 4 if beat >= 0.0 else -1
	var through := beat - floorf(beat)
	var water := size.y - 30.0
	for i in 4:
		var middle := Vector2(APART * (i + 0.5), water)
		# (the red one, the downbeat, is the last of the four)
		var leaping := now >= 0 and i == (now + 3) % 4
		# the water it swims in: a short line of it, with a ripple where it leaves and lands
		var sea := Color(UI.TEAL, 0.75 if leaping else 0.4)
		for k in 9:
			var x := middle.x - 63.0 + k * 14.0
			draw_rect(Rect2(x, water + 16.0 + (5.0 if (k + i) % 2 == 0 else 0.0), 14.0, 5.0), sea)
		var up := 0.0
		var tilt := 0.0
		if leaping:
			up = sin(through * PI) * LEAP
			tilt = lerpf(-0.75, 0.75, through)
			if through < 0.2 or through > 0.8:
				for side: float in [-1.0, 1.0]:
					draw_rect(Rect2(middle.x + side * 48.0 - 3.0, water - 6.0, 7.0, 7.0), Color.WHITE)
					draw_rect(Rect2(middle.x + side * 62.0 - 3.0, water + 4.0, 7.0, 7.0), Color.WHITE)
		# (the others lie low in the water, half under it, and dim)
		# (the same salmon as the sign by the score, red for the downbeat and silver for the rest)
		_sign(middle + Vector2(0.0, -up - (4.0 if leaping else -6.0)), 112.0, i == 3, tilt, 1.0 if leaping else 0.5)


# The sign by the count of the pack: a salmon drawn in clean shapes (not in big pixels like
# the beat keepers), a spawner, red with a green head, facing right. `long` is its length.
func _sign(middle: Vector2, long: float, spawner := true, tilt := 0.0, dim := 1.0) -> void:
	var k := long / 100.0
	var red := Color(0.92, 0.2, 0.16, dim) if spawner else Color(0.7, 0.8, 0.9, dim)
	var dark := Color(0.6, 0.08, 0.08, dim) if spawner else Color(0.2, 0.36, 0.54, dim)
	var pale := Color(1.0, 0.7, 0.58, dim) if spawner else Color(0.96, 0.98, 1.0, dim)
	var green := Color(0.34, 0.56, 0.24, dim) if spawner else Color(0.32, 0.46, 0.6, dim)
	var ink := Color(UI.INK, dim)
	# (turned about its middle: nose up as it leaves the water, nose down coming in)
	draw_set_transform(middle, tilt, Vector2.ONE)
	middle = Vector2.ZERO
	# (points are in hundredths of its length, from its middle; y down)
	var at := func(points: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p: Vector2 in points:
			out.append(middle + p * k)
		return out
	var body := [Vector2(-30, 0), Vector2(-22, -9), Vector2(-8, -15), Vector2(8, -16), Vector2(22, -13), Vector2(34, -7),
			Vector2(46, -1), Vector2(40, 6), Vector2(26, 11), Vector2(8, 14), Vector2(-10, 12), Vector2(-24, 6)]
	var tail := [Vector2(-28, -1), Vector2(-50, -15), Vector2(-43, 0), Vector2(-50, 14), Vector2(-28, 2)]
	var back_fin := [Vector2(-4, -15), Vector2(6, -25), Vector2(14, -15)]
	var under_fin := [Vector2(-12, 11), Vector2(-17, 21), Vector2(-4, 13)]
	var chest_fin := [Vector2(14, 10), Vector2(8, 22), Vector2(22, 12)]
	# an ink edge all round it: the same shapes, a little bigger, drawn first
	for shape: Array in [body, tail, back_fin, under_fin, chest_fin]:
		var edge := []
		for p: Vector2 in shape:
			edge.append(p * 1.0 + p.normalized() * 3.2)
		draw_colored_polygon(at.call(edge), ink)
	draw_colored_polygon(at.call(tail), dark)
	draw_colored_polygon(at.call(back_fin), dark)
	draw_colored_polygon(at.call(under_fin), dark)
	draw_colored_polygon(at.call(chest_fin), dark)
	draw_colored_polygon(at.call(body), red)
	# its back darker, its belly pale, its head green with a hooked jaw
	draw_colored_polygon(at.call([Vector2(-30, 0), Vector2(-22, -9), Vector2(-8, -15), Vector2(8, -16), Vector2(22, -13), Vector2(22, -7), Vector2(-24, -3)]), dark)
	draw_colored_polygon(at.call([Vector2(-24, 6), Vector2(-10, 12), Vector2(8, 14), Vector2(22, 11), Vector2(22, 6), Vector2(-22, 3)]), pale)
	draw_colored_polygon(at.call([Vector2(22, -13), Vector2(34, -7), Vector2(46, -1), Vector2(44, 4), Vector2(40, 6), Vector2(26, 11), Vector2(19, 0)]), green)
	draw_colored_polygon(at.call([Vector2(40, -3), Vector2(48, -2), Vector2(47, 5), Vector2(43, 3)]), green.darkened(0.25))
	draw_circle(middle + Vector2(33, -4) * k, 3.4 * k, Color(0.98, 0.9, 0.4, dim))
	draw_circle(middle + Vector2(33.6, -4) * k, 1.9 * k, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
