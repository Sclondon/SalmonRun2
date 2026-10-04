extends Control
## A little chunky globe for the map and the travel screen. Stages are pins on the Earth, and
## the journey is a red line that draws itself from one to the next while the globe turns to
## follow it, the way the travel maps do in an adventure film.

signal arrived

const UI := preload("res://scripts/ui/ui_kit.gd")
const Levels := preload("res://scripts/world/levels.gd")

## Size of the squares the land is drawn with, in degrees.
const CELL := 5
const LANE_COLORS := [UI.CYAN, UI.ORANGE, UI.LIME]
const OCEAN := Color(0.05, 0.2, 0.42)
const OCEAN_RIM := Color(0.02, 0.08, 0.22)
const LAND := Color(0.3, 0.62, 0.26)
const ICE := Color(0.92, 0.96, 1.0)

# Very rough coastlines as [longitude, latitude] points: at this size only the shapes matter.
const COASTS := [
	# North America
	[[-168, 66], [-156, 71], [-141, 70], [-125, 70], [-110, 68], [-95, 69], [-82, 70], [-78, 62], [-64, 60], [-56, 52],
			[-66, 45], [-70, 42], [-76, 35], [-81, 31], [-80, 25], [-84, 30], [-90, 29], [-97, 26], [-97, 20], [-90, 18],
			[-87, 15], [-83, 9], [-78, 8], [-85, 11], [-92, 15], [-105, 20], [-110, 24], [-115, 31], [-120, 34], [-124, 40],
			[-124, 48], [-130, 55], [-140, 60], [-152, 59], [-160, 55], [-165, 60]],
	# Greenland
	[[-55, 60], [-42, 60], [-22, 70], [-20, 80], [-45, 83], [-65, 80], [-70, 76], [-55, 68]],
	# South America
	[[-78, 8], [-72, 12], [-62, 10], [-50, 0], [-35, -6], [-39, -15], [-48, -26], [-58, -38], [-66, -46], [-70, -54],
			[-75, -48], [-72, -35], [-70, -18], [-78, -8], [-81, -3]],
	# Europe and Asia
	[[-10, 36], [-9, 43], [-2, 44], [-5, 48], [3, 51], [8, 54], [5, 60], [12, 65], [25, 71], [40, 67], [60, 69], [70, 73],
			[90, 76], [110, 74], [130, 72], [150, 70], [170, 69], [180, 66], [178, 62], [163, 58], [156, 52], [162, 56],
			[150, 59], [140, 54], [135, 44], [128, 40], [126, 35], [122, 38], [118, 38], [122, 30], [118, 24], [110, 21],
			[107, 16], [109, 11], [105, 9], [100, 13], [99, 8], [103, 2], [98, 8], [94, 17], [90, 22], [86, 20], [80, 15],
			[78, 8], [73, 18], [67, 24], [57, 26], [52, 28], [48, 30], [56, 24], [52, 16], [44, 12], [40, 18], [34, 28],
			[35, 36], [27, 37], [22, 38], [12, 44], [8, 44], [3, 43], [-1, 37]],
	# Africa
	[[-17, 15], [-16, 22], [-9, 30], [-5, 36], [10, 37], [20, 32], [32, 31], [35, 24], [43, 12], [51, 11], [41, -2],
			[40, -15], [35, -24], [27, -34], [18, -34], [12, -18], [13, -5], [9, 4], [-5, 5], [-13, 9]],
	# Australia
	[[114, -22], [122, -18], [130, -12], [136, -12], [141, -13], [142, -11], [146, -19], [153, -26], [150, -37],
			[144, -38], [137, -34], [130, -32], [116, -35]],
	# Japan, Borneo, Sumatra, New Guinea, the Philippines
	[[130, 31], [136, 34], [141, 36], [142, 42], [145, 44], [141, 45], [139, 38], [133, 35]],
	[[109, 1], [115, 7], [119, 5], [117, -3], [110, -2]],
	[[95, 5], [104, -3], [106, -6], [100, -1]],
	[[131, -1], [141, -3], [150, -6], [147, -10], [141, -9], [134, -4]],
	[[120, 18], [122, 14], [126, 8], [124, 6], [121, 12]],
]

static var _cells: Array = []  # [centre, corner, corner, corner, corner, colour] for each square of land

## The stage the pin is on and its name is shown for.
var selected := -1

var _static: Array[int] = []
var _from := -1
var _to := -1
var _progress := 1.0
var _duration := 1.4
var _view := Vector3(0, 0, 1)
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cells.is_empty():
		_build_land()


static func to_vec(at: Vector2) -> Vector3:
	var lat := deg_to_rad(at.x)
	var lon := deg_to_rad(at.y)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


static func _stage_vec(id: int) -> Vector3:
	return to_vec(Levels.LIST[id].at)


## Shows the journey so far (`done`, in order) and draws the next leg from `from` to `to`.
## With no `from` it just turns to look at `to`.
func show_path(done: Array[int], from: int, to: int, duration := 1.4) -> void:
	_static = done.duplicate()
	_from = from if from != to else -1
	_to = to
	selected = to
	_duration = duration
	_progress = 0.0 if _from != -1 else 1.0
	if _from != -1 and not is_visible_in_tree():
		_view = _stage_vec(_from)
	queue_redraw()


## Jumps straight to looking at a stage (no turning).
func look_at_stage(id: int) -> void:
	_view = _stage_vec(id)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _progress < 1.0:
		_progress = minf(_progress + delta / _duration, 1.0)
		if _progress >= 1.0:
			arrived.emit()
	if _to != -1:
		_view = _view.slerp(_head(), 1.0 - exp(-delta * 4.0)).normalized()
	queue_redraw()


## Where the line has got to.
func _head() -> Vector3:
	if _from == -1:
		return _stage_vec(_to)
	return _stage_vec(_from).slerp(_stage_vec(_to), smoothstep(0.0, 1.0, _progress))


static func _build_land() -> void:
	var half := CELL * 0.5
	for lat in range(-90, 90, CELL):
		for lon in range(-180, 180, CELL):
			var c := Vector2(lon + half, lat + half)
			var ice := c.y < -68.0
			if not ice and not _is_land(c):
				continue
			var col := ICE if ice or c.y > 72.0 else LAND.lerp(Color(0.62, 0.6, 0.3), clampf(1.0 - absf(absf(c.y) - 25.0) / 12.0, 0.0, 1.0) * 0.6)
			_cells.append([to_vec(Vector2(c.y, c.x)), to_vec(Vector2(lat, lon)), to_vec(Vector2(lat, lon + CELL)),
					to_vec(Vector2(lat + CELL, lon + CELL)), to_vec(Vector2(lat + CELL, lon)), col])


static func _is_land(p: Vector2) -> bool:
	for coast: Array in COASTS:
		var inside := false
		var j := coast.size() - 1
		for i in coast.size():
			var a := Vector2(coast[i][0], coast[i][1])
			var b := Vector2(coast[j][0], coast[j][1])
			if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
				inside = not inside
			j = i
		if inside:
			return true
	return false


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 8.0
	var c := size * 0.5
	# turn the Earth so the point of interest faces us (tilting only part of the way to it)
	var lat0 := asin(clampf(_view.y, -1.0, 1.0)) * 0.75
	var lon0 := atan2(_view.x, _view.z)
	var m := Basis(Vector3.RIGHT, lat0) * Basis(Vector3.UP, -lon0)
	draw_circle(c, r + 7.0, UI.INK)
	draw_circle(c, r + 3.0, Color(UI.CYAN, 0.55))
	draw_circle(c, r, OCEAN_RIM)
	draw_circle(c - Vector2(r, r) * 0.1, r * 0.86, OCEAN)
	for cell: Array in _cells:
		var mid: Vector3 = m * (cell[0] as Vector3)
		if mid.z < 0.04:
			continue
		var pts := PackedVector2Array()
		for k in range(1, 5):
			var p: Vector3 = m * (cell[k] as Vector3)
			pts.append(c + Vector2(p.x, -p.y) * r)
		draw_colored_polygon(pts, (cell[5] as Color) * Color(Color.WHITE * (0.5 + 0.5 * mid.z), 1.0))
	# the journey: every leg already swum, then the one being drawn
	for i in _static.size() - 1:
		_leg(m, c, r, _stage_vec(_static[i]), _stage_vec(_static[i + 1]), 1.0)
	if _from != -1:
		_leg(m, c, r, _stage_vec(_from), _stage_vec(_to), smoothstep(0.0, 1.0, _progress))
	# pins
	var font := UI.font()
	for id in Levels.LIST.size():
		var p: Vector3 = m * _stage_vec(id)
		if p.z < 0.0:
			continue
		var at := c + Vector2(p.x, -p.y) * r
		var col: Color = LANE_COLORS[Levels.LIST[id].lane]
		var here := id == selected
		var pr := (7.0 + sin(_t * 6.0) * 2.0) if here else 4.0
		draw_circle(at, pr + 2.5, UI.INK)
		draw_circle(at, pr, Color.WHITE if here else col)
	if selected != -1 and _progress >= 1.0:
		var p: Vector3 = m * _stage_vec(selected)
		if p.z > 0.0:
			var at := c + Vector2(p.x, -p.y) * r + Vector2(-200.0, -18.0)
			var text: String = Levels.LIST[selected].name
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 22, 8, UI.INK)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 22, Color.WHITE)


## Draws the great-circle line from a to b, as far as `upto` (0..1), skipping the far side.
func _leg(m: Basis, c: Vector2, r: float, a: Vector3, b: Vector3, upto: float) -> void:
	var steps := maxi(int(rad_to_deg(a.angle_to(b)) / 3.0), 2)
	var prev := Vector2.ZERO
	var prev_ok := false
	var count := int(ceilf(steps * upto))
	for i in count + 1:
		# lifted a little off the surface so it reads as a line over the map
		var p: Vector3 = m * (a.slerp(b, minf(float(i) / steps, upto)) * 1.02)
		var ok := p.z > 0.0
		var at := c + Vector2(p.x, -p.y) * r
		if ok and prev_ok:
			draw_line(prev, at, UI.INK, 8.0)
			draw_line(prev, at, UI.RED, 4.0)
		prev = at
		prev_ok = ok
	if upto < 1.0 and prev_ok:
		draw_circle(prev, 7.0, UI.INK)
		draw_circle(prev, 4.5, Color.WHITE)
