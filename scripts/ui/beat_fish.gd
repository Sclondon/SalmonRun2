extends Control
## The beat keeper: a row of four little pixel salmon along the bottom of the screen, one for
## each beat of the bar. The one whose beat it is leaps clear of the water, nose up on the way
## and nose down coming in, and is back in it as the next one goes. The first of the four,
## the downbeat, is a red spawner; the others are silver.

const UI := preload("res://scripts/ui/ui_kit.gd")

## The salmon, a pixel to a letter, facing right: b back, s side, w belly, h head, e eye,
## f fin and tail.
const FISH := [
	"......bbb.....",
	"f...bbbbbbbb..",
	"ff.bsssssssshh",
	".fffssssssshe.",
	"ff.swwwwwwshh.",
	"f...wwwfww....",
	"........f.....",
]
## How big a pixel of it is, how far apart the four are, and how high the leap is.
const PIXEL := 6.0
const APART := 112.0
const LEAP := 42.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(APART * 4.0, 110.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var beat := Music.beat_float()
	var now := int(floorf(beat)) % 4 if beat >= 0.0 else -1
	var through := beat - floorf(beat)
	var water := size.y - 22.0
	var wide := float(str(FISH[0]).length()) * PIXEL
	var tall := FISH.size() * PIXEL
	for i in 4:
		var middle := Vector2(APART * (i + 0.5), water)
		var leaping := i == now
		# the water it swims in: a short line of it, with a ripple where it leaves and lands
		var sea := Color(UI.TEAL, 0.75 if leaping else 0.4)
		for k in 9:
			var x := middle.x - 54.0 + k * 12.0
			draw_rect(Rect2(x, water + 10.0 + (PIXEL if (k + i) % 2 == 0 else 0.0), 12.0, PIXEL), sea)
		var up := 0.0
		var tilt := 0.0
		if leaping:
			up = sin(through * PI) * LEAP
			tilt = lerpf(-0.75, 0.75, through)
			if through < 0.2 or through > 0.8:
				for side: float in [-1.0, 1.0]:
					draw_rect(Rect2(middle.x + side * 34.0 - 3.0, water - 6.0, PIXEL, PIXEL), Color.WHITE)
					draw_rect(Rect2(middle.x + side * 46.0 - 3.0, water + 2.0, PIXEL, PIXEL), Color.WHITE)
		# (the others lie low in the water, half under it, and dim)
		var dim := 1.0 if leaping else 0.45
		var red := i == 0
		var inks := {
			"b": Color(0.62, 0.1, 0.1) if red else Color(0.16, 0.3, 0.44),
			"s": Color(0.94, 0.26, 0.2) if red else Color(0.72, 0.8, 0.88),
			"w": Color(1.0, 0.72, 0.6) if red else Color(0.96, 0.98, 1.0),
			"h": Color(0.36, 0.56, 0.24) if red else Color(0.3, 0.44, 0.56),
			"e": Color(0.05, 0.05, 0.08),
			"f": Color(0.7, 0.14, 0.12) if red else Color(0.36, 0.48, 0.6),
		}
		draw_set_transform(middle + Vector2(0.0, -up - (2.0 if leaping else -4.0)), tilt, Vector2.ONE)
		for row in FISH.size():
			var line: String = FISH[row]
			for col in line.length():
				var ink := line[col]
				if ink == ".":
					continue
				draw_rect(Rect2(col * PIXEL - wide * 0.5, row * PIXEL - tall * 0.5, PIXEL, PIXEL), Color(inks[ink], dim))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
