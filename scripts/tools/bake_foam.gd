extends SceneTree
## Makes textures/foam_noise.png, the pattern the water's foam is cut from: soft clumps with
## a lace of cells through them, which wraps round at its edges so that it can be laid side by
## side for ever. Where the water shader finds it bright there is foam; how bright it has to
## be is what makes more foam or less.
##
##     godot --path . -s scripts/tools/bake_foam.gd
##
## (Or paint one: any grey picture that wraps will do. Set it on materials/water.tres.)

const SIZE := 256


func _initialize() -> void:
	var values := PackedFloat32Array()
	values.resize(SIZE * SIZE)
	var low := INF
	var high := -INF
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y) / SIZE
			# clumps: smooth noise at four sizes
			var v := 0.0
			var weight := 0.5
			var cells := 4
			for octave in 4:
				v += _smooth(p * cells, cells, octave) * weight
				weight *= 0.5
				cells *= 2
			# lace: bright along the walls between cells, at two sizes
			v += (_cells(p * 6.0, 6, 11) - 0.5) * 0.3
			v += (_cells(p * 14.0, 14, 23) - 0.5) * 0.16
			values[y * SIZE + x] = v
			low = minf(low, v)
			high = maxf(high, v)
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var v := (values[y * SIZE + x] - low) / (high - low)
			image.set_pixel(x, y, Color(v, v, v))
	image.save_png("res://textures/foam_noise.png")
	print("foam_noise.png written")
	quit()


func _corner(x: int, y: int, period: int, salt: int) -> int:
	var h := (posmod(x, period) * 668265261) ^ (posmod(y, period) * 374761393) ^ (salt * 1274126177)
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	return (h ^ (h >> 16)) & 0x7fffffff


## Smooth noise that repeats every `period` squares: a slope at each corner, blended.
func _smooth(p: Vector2, period: int, salt: int) -> float:
	var ix := floori(p.x)
	var iy := floori(p.y)
	var f := Vector2(p.x - ix, p.y - iy)
	var u := Vector2(f.x * f.x * f.x * (f.x * (f.x * 6.0 - 15.0) + 10.0), f.y * f.y * f.y * (f.y * (f.y * 6.0 - 15.0) + 10.0))
	var got: Array[float] = []
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var angle := float(_corner(ix + c.x, iy + c.y, period, salt)) / 0x7fffffff * TAU
		got.append(Vector2(cos(angle), sin(angle)).dot(f - Vector2(c)))
	return lerpf(lerpf(got[0], got[1], u.x), lerpf(got[2], got[3], u.x), u.y)


## Cells, repeating every `period`: 0 at the middle of each, 1 on the walls between them.
func _cells(p: Vector2, period: int, salt: int) -> float:
	var ix := floori(p.x)
	var iy := floori(p.y)
	var nearest := 9.0
	var second := 9.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var h := _corner(ix + dx, iy + dy, period, salt)
			var point := Vector2(ix + dx + float(h & 1023) / 1023.0, iy + dy + float((h >> 10) & 1023) / 1023.0)
			var d := p.distance_to(point)
			if d < nearest:
				second = nearest
				nearest = d
			elif d < second:
				second = d
	return 1.0 - clampf((second - nearest) * 2.2, 0.0, 1.0)
