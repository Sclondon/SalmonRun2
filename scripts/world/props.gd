extends RefCounted
## Procedural low-poly prop library. Every builder returns an ArrayMesh with vertex colours.
## A vertex colour alpha below 1 marks a glowing face (see psx.gdshader).

const MB := preload("res://scripts/util/mesh_builder.gd")

const BOX_FACES := [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]]


static func glow(c: Color, amount: float) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - amount)


static func vary(c: Color, rng: RandomNumberGenerator, amount := 0.06) -> Color:
	var k := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + k, 0.0, 1.0), clampf(c.g + k * 1.2, 0.0, 1.0), clampf(c.b + k, 0.0, 1.0), c.a)


static func shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


# ------------------------------------------------------------------ primitives

## Tapered cylinder from a to b.
static func frustum(mb: MB, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, col: Color,
		cap := true, rng: RandomNumberGenerator = null) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var c := col if rng == null else vary(col, rng, 0.04)
		mb.quad(a + d0 * ra, a + d1 * ra, b + d1 * rb, b + d0 * rb, c, d0 + d1)
		if cap and rb > 0.001:
			mb.tri(b, b + d0 * rb, b + d1 * rb, c, axis)


## Jittered low-poly ellipsoid.
static func blob(mb: MB, c: Vector3, r: Vector3, rng: RandomNumberGenerator, col: Color,
		lon := 6, lat := 4, jitter := 0.18, cvar := 0.06) -> void:
	var rows: Array = []
	for j in lat + 1:
		var th := PI * j / lat
		var row: Array[Vector3] = []
		if j == 0 or j == lat:
			var pole := c + Vector3(0.0, cos(th), 0.0) * r * (1.0 + rng.randf_range(-jitter, jitter))
			for i in lon:
				row.append(pole)
		else:
			for i in lon:
				var ph := TAU * (i + (0.5 if j % 2 == 1 else 0.0)) / lon
				var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				row.append(c + dir * r * (1.0 + rng.randf_range(-jitter, jitter)))
		rows.append(row)
	for j in lat:
		var r0: Array[Vector3] = rows[j]
		var r1: Array[Vector3] = rows[j + 1]
		for i in lon:
			var i2 := (i + 1) % lon
			var cc := shade(vary(col, rng, cvar), 1.0 - 0.3 * float(j) / lat)
			mb.tri_out(r0[i], r0[i2], r1[i2], cc, c)
			mb.tri_out(r0[i], r1[i2], r1[i], cc, c)


static func box(mb: MB, c: Vector3, size: Vector3, col: Color, rng: RandomNumberGenerator = null,
		jitter := 0.0, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for k in 8:
		var p := Vector3(h.x * (1.0 if (k & 1) != 0 else -1.0), h.y * (1.0 if (k & 2) != 0 else -1.0),
				h.z * (1.0 if (k & 4) != 0 else -1.0))
		if rng != null and jitter > 0.0:
			p += Vector3(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		corners.append(c + basis * p)
	for f: Array in BOX_FACES:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var cc: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		var out := (a + b + cc + d) * 0.25 - c
		var k := 1.1 if out.y > 0.3 * out.length() else (0.7 if out.y < -0.3 * out.length() else 0.9)
		var col2 := shade(col if rng == null else vary(col, rng, 0.04), k)
		mb.quad(a, b, cc, d, col2, out)


## A flat leaf/blade strip from `base`, heading along `dir`, arching up then drooping.
static func blade(mb: MB, base: Vector3, dir: Vector3, length: float, width: float, lift: float,
		droop: float, col: Color, rng: RandomNumberGenerator, segs := 3) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	var prev_l := base
	var prev_r := base
	for k in segs:
		var t := float(k + 1) / segs
		var p := base + dir * length * t + Vector3.UP * (lift * t - droop * t * t) * length
		var w := width * sin(PI * minf(t, 0.95))
		var l := p - side * w
		var r := p + side * w
		mb.quad(prev_l, prev_r, r, l, vary(col, rng, 0.05), Vector3.UP)
		prev_l = l
		prev_r = r


# ------------------------------------------------------------------ the salmon

static func salmon() -> ArrayMesh:
	var mb := MB.new()
	# z, half-width, half-height, y-centre (nose at -Z, which is Godot's forward)
	var rings := [
		[-1.20, 0.03, 0.03, -0.02],
		[-0.95, 0.17, 0.21, 0.00],
		[-0.55, 0.26, 0.37, 0.05],
		[-0.10, 0.28, 0.42, 0.07],
		[0.35, 0.22, 0.30, 0.03],
		[0.72, 0.11, 0.15, 0.00],
		[0.92, 0.05, 0.08, 0.00],
	]
	var green := Color(0.30, 0.50, 0.20)
	var red := Color(0.90, 0.14, 0.10)
	var dark_red := Color(0.58, 0.07, 0.07)
	var belly := Color(0.98, 0.66, 0.52)
	var jaw := Color(0.85, 0.88, 0.72)
	var sides := 8
	for k in rings.size() - 1:
		var ra: Array = rings[k]
		var rb: Array = rings[k + 1]
		var zmid: float = (ra[0] + rb[0]) * 0.5
		var axis := Vector3(0.0, (ra[3] + rb[3]) * 0.5, zmid)
		for i in sides:
			var a0 := TAU * i / sides + PI / sides
			var a1 := TAU * (i + 1) / sides + PI / sides
			var pa0 := Vector3(cos(a0) * ra[1], ra[3] + sin(a0) * ra[2], ra[0])
			var pa1 := Vector3(cos(a1) * ra[1], ra[3] + sin(a1) * ra[2], ra[0])
			var pb0 := Vector3(cos(a0) * rb[1], rb[3] + sin(a0) * rb[2], rb[0])
			var pb1 := Vector3(cos(a1) * rb[1], rb[3] + sin(a1) * rb[2], rb[0])
			var sn := sin((a0 + a1) * 0.5)
			var col := green if zmid < -0.6 else red
			if sn > 0.6 and zmid >= -0.6:
				col = dark_red
			if sn < -0.5:
				col = jaw if zmid < -0.6 else belly
			mb.tri_out(pa0, pa1, pb1, col, axis)
			mb.tri_out(pa0, pb1, pb0, col, axis)
	# end caps
	var tip := Vector3(0.0, -0.02, -1.26)
	var tail_end := Vector3(0.0, 0.0, 0.95)
	for i in sides:
		var a0 := TAU * i / sides + PI / sides
		var a1 := TAU * (i + 1) / sides + PI / sides
		mb.tri(tip, Vector3(cos(a0) * 0.03, -0.02 + sin(a0) * 0.03, -1.2), Vector3(cos(a1) * 0.03, -0.02 + sin(a1) * 0.03, -1.2), green, Vector3.FORWARD)
		mb.tri(tail_end, Vector3(cos(a0) * 0.05, sin(a0) * 0.08, 0.92), Vector3(cos(a1) * 0.05, sin(a1) * 0.08, 0.92), dark_red, Vector3.BACK)
	# forked tail
	var fin := Color(0.62, 0.10, 0.08)
	var t0 := Vector3(0.0, 0.08, 0.9)
	var t1 := Vector3(0.0, -0.08, 0.9)
	var notch := Vector3(0.0, 0.0, 1.16)
	mb.tri(t0, Vector3(0.0, 0.52, 1.42), notch, fin, Vector3.RIGHT)
	mb.tri(t1, notch, Vector3(0.0, -0.46, 1.40), fin, Vector3.RIGHT)
	mb.tri(t0, notch, t1, fin, Vector3.RIGHT)
	# dorsal, adipose, anal fins
	mb.tri(Vector3(0.0, 0.47, -0.35), Vector3(0.0, 0.82, -0.05), Vector3(0.0, 0.45, 0.15), dark_red, Vector3.RIGHT)
	mb.tri(Vector3(0.0, 0.3, 0.55), Vector3(0.0, 0.43, 0.7), Vector3(0.0, 0.26, 0.72), dark_red, Vector3.RIGHT)
	mb.tri(Vector3(0.0, -0.28, 0.45), Vector3(0.0, -0.46, 0.64), Vector3(0.0, -0.18, 0.7), fin, Vector3.RIGHT)
	# kype (the hooked spawning jaw)
	mb.tri(Vector3(0.0, -0.04, -1.18), Vector3(0.0, -0.16, -1.3), Vector3(0.0, -0.12, -1.02), jaw, Vector3.RIGHT)
	for sx: float in [-1.0, 1.0]:
		# pectoral + pelvic fins
		mb.tri(Vector3(sx * 0.24, -0.18, -0.55), Vector3(sx * 0.62, -0.4, -0.28), Vector3(sx * 0.24, -0.27, -0.25), fin, Vector3.UP)
		mb.tri(Vector3(sx * 0.14, -0.33, 0.2), Vector3(sx * 0.34, -0.5, 0.42), Vector3(sx * 0.12, -0.3, 0.42), fin, Vector3.UP)
		# eye
		var e := Vector3(sx * 0.205, 0.1, -0.82)
		mb.quad(e + Vector3(0, 0.07, -0.06), e + Vector3(0, 0.07, 0.06), e + Vector3(0, -0.06, 0.06), e + Vector3(0, -0.06, -0.06), Color(0.95, 0.85, 0.3), Vector3(sx, 0, 0))
		var p := e + Vector3(sx * 0.005, 0.0, 0.0)
		mb.quad(p + Vector3(0, 0.04, -0.03), p + Vector3(0, 0.04, 0.03), p + Vector3(0, -0.03, 0.03), p + Vector3(0, -0.03, -0.03), Color(0.02, 0.02, 0.02), Vector3(sx, 0, 0))
	return mb.build()


# ------------------------------------------------------------------ jungle

static func jungle_tree(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var h := rng.randf_range(9.0, 15.0)
	var trunk := Color(0.36, 0.26, 0.18)
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 0.9
	var mid := Vector3(0.0, h * 0.55, 0.0) + lean * 0.5
	var top := Vector3(0.0, h, 0.0) + lean
	frustum(mb, Vector3(0.0, -0.8, 0.0), mid, 0.6, 0.42, 5, trunk, false, rng)
	frustum(mb, mid, top, 0.42, 0.25, 5, trunk, false, rng)
	# buttress roots
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf()
		var d := Vector3(cos(a), 0.0, sin(a))
		mb.tri(Vector3(0.0, 2.2, 0.0) + d * 0.3, d * 1.6 + Vector3(0.0, -0.3, 0.0), d * 0.4 + Vector3(0.0, -0.3, 0.0), shade(trunk, 0.8), d.cross(Vector3.UP))
	var greens := [Color(0.13, 0.42, 0.16), Color(0.22, 0.55, 0.18), Color(0.10, 0.33, 0.20)]
	for i in rng.randi_range(3, 5):
		var off := Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(-1.0, 1.5), rng.randf_range(-2.5, 2.5))
		blob(mb, top + off, Vector3(rng.randf_range(2.6, 4.0), rng.randf_range(1.4, 2.3), rng.randf_range(2.6, 4.0)), rng, greens[rng.randi() % 3], 6, 3, 0.2)
	# hanging vines
	for i in rng.randi_range(1, 3):
		var vp := top + Vector3(rng.randf_range(-2.5, 2.5), -1.0, rng.randf_range(-2.5, 2.5))
		var vl := rng.randf_range(3.0, 6.0)
		mb.quad(vp, vp + Vector3(0.12, 0.0, 0.0), vp + Vector3(0.1, -vl, 0.05), vp + Vector3(0.0, -vl, 0.05), Color(0.16, 0.36, 0.1), Vector3.BACK)
	return mb.build()


static func palm(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var h := rng.randf_range(6.0, 10.0)
	var a := rng.randf() * TAU
	var bend := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(1.0, 3.0)
	var segs := 6
	var prev := Vector3(0.0, -0.5, 0.0)
	for k in segs:
		var t := float(k + 1) / segs
		var p := bend * t * t + Vector3(0.0, h * t, 0.0)
		var col := Color(0.52, 0.40, 0.26) if k % 2 == 0 else Color(0.42, 0.32, 0.2)
		frustum(mb, prev, p, 0.34 - 0.03 * k, 0.31 - 0.03 * k, 5, col, false)
		prev = p
	var top := prev
	for k in 8:
		var fa := TAU * k / 8.0 + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(fa), 0.0, sin(fa))
		blade(mb, top, dir, rng.randf_range(3.5, 5.0), 0.55, 0.45, 0.95, Color(0.24, 0.58, 0.17), rng, 4)
	for k in 3:
		blob(mb, top + Vector3(rng.randf_range(-0.3, 0.3), -0.35, rng.randf_range(-0.3, 0.3)), Vector3(0.22, 0.22, 0.22), rng, Color(0.35, 0.25, 0.12), 5, 3, 0.1)
	return mb.build()


static func fern(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var count := rng.randi_range(6, 9)
	var col := Color(0.2, 0.5, 0.15).lerp(Color(0.35, 0.6, 0.1), rng.randf())
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.2, 0.2)
		blade(mb, Vector3.ZERO, Vector3(cos(a), 0.0, sin(a)), rng.randf_range(1.4, 2.4), 0.3, 0.9, 1.0, col, rng, 3)
	return mb.build()


static func bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	for k in rng.randi_range(2, 3):
		var c := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 0.9), rng.randf_range(-1.0, 1.0))
		blob(mb, c, Vector3(1.3, 1.0, 1.3) * rng.randf_range(0.8, 1.3), rng, Color(0.14, 0.38, 0.14), 6, 3, 0.2)
	return mb.build()


static func rock(rng: RandomNumberGenerator, col := Color(0.46, 0.44, 0.40)) -> ArrayMesh:
	var mb := MB.new()
	blob(mb, Vector3(0.0, 0.2, 0.0), Vector3(1.0, 0.75, 1.0), rng, col, 6, 3, 0.28, 0.05)
	# a little moss cap
	blob(mb, Vector3(0.0, 0.75, 0.0), Vector3(0.6, 0.18, 0.6), rng, Color(0.28, 0.48, 0.18), 5, 2, 0.2)
	return mb.build()


static func flower(rng: RandomNumberGenerator, petal: Color) -> ArrayMesh:
	var mb := MB.new()
	var h := rng.randf_range(0.6, 1.3)
	frustum(mb, Vector3.ZERO, Vector3(0.0, h, 0.0), 0.05, 0.04, 3, Color(0.2, 0.45, 0.12), false)
	blade(mb, Vector3(0.0, h * 0.3, 0.0), Vector3(1, 0, 0), 0.6, 0.18, 0.4, 0.8, Color(0.2, 0.5, 0.15), rng, 2)
	var top := Vector3(0.0, h, 0.0)
	var g := glow(petal, 0.7)
	for k in 5:
		var a := TAU * k / 5.0
		var d := Vector3(cos(a), 0.25, sin(a))
		var s := Vector3(cos(a + 0.6), 0.25, sin(a + 0.6))
		mb.tri(top, top + d * 0.45, top + s * 0.45, g, Vector3.UP)
	blob(mb, top + Vector3(0.0, 0.05, 0.0), Vector3(0.1, 0.1, 0.1), rng, glow(Color(1.0, 0.95, 0.4), 0.8), 4, 2, 0.0)
	return mb.build()


static func mushroom(rng: RandomNumberGenerator, cap: Color) -> ArrayMesh:
	var mb := MB.new()
	for k in rng.randi_range(1, 3):
		var o := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
		var h := rng.randf_range(0.5, 1.4)
		var r := rng.randf_range(0.35, 0.7)
		frustum(mb, o, o + Vector3(0.0, h, 0.0), r * 0.25, r * 0.2, 5, Color(0.9, 0.88, 0.78), false)
		blob(mb, o + Vector3(0.0, h, 0.0), Vector3(r, r * 0.45, r), rng, glow(cap, 0.75), 6, 2, 0.1)
	return mb.build()


static func hill(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var r := rng.randf_range(35.0, 65.0)
	blob(mb, Vector3.ZERO, Vector3(r, r * rng.randf_range(0.6, 1.1), r), rng, Color(0.08, 0.26, 0.14), 9, 4, 0.18, 0.04)
	return mb.build()


static func lily_pad(rng: RandomNumberGenerator, with_flower: bool) -> ArrayMesh:
	var mb := MB.new()
	var r := rng.randf_range(0.6, 1.1)
	var col := Color(0.22, 0.55, 0.2)
	for k in 7:
		var a0 := TAU * (k + 0.5) / 8.0
		var a1 := TAU * (k + 1.5) / 8.0
		mb.tri(Vector3.ZERO, Vector3(cos(a0), 0.0, sin(a0)) * r, Vector3(cos(a1), 0.0, sin(a1)) * r, vary(col, rng, 0.05), Vector3.UP)
	if with_flower:
		var pink := glow(Color(1.0, 0.45, 0.75), 0.5)
		for k in 6:
			var a := TAU * k / 6.0
			mb.tri(Vector3(0.0, 0.05, 0.0), Vector3(cos(a) * 0.35, 0.35, sin(a) * 0.35), Vector3(cos(a + 0.8) * 0.35, 0.3, sin(a + 0.8) * 0.35), pink, Vector3.UP)
	return mb.build()


static func reeds(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	for k in rng.randi_range(5, 9):
		var o := Vector3(rng.randf_range(-0.7, 0.7), -0.5, rng.randf_range(-0.7, 0.7))
		var h := rng.randf_range(1.5, 3.0)
		var lean := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
		var col := Color(0.45, 0.55, 0.2).lerp(Color(0.3, 0.5, 0.15), rng.randf())
		mb.tri(o, o + Vector3(0.12, 0.0, 0.0), o + lean + Vector3(0.05, h, 0.0), col, Vector3.BACK)
		if rng.randf() < 0.4:
			frustum(mb, o + lean * 0.8 + Vector3(0.05, h * 0.75, 0.0), o + lean * 0.9 + Vector3(0.05, h * 0.9, 0.0), 0.09, 0.09, 4, Color(0.4, 0.25, 0.12))
	return mb.build()


# ------------------------------------------------------------------ set pieces

static func speaker_stack(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var black := Color(0.09, 0.09, 0.11)
	var cones := [glow(Color(1.0, 0.25, 0.65), 0.65), glow(Color(0.2, 1.0, 0.9), 0.65)]
	var cabinets := [Vector2(-1.05, 1.0), Vector2(1.05, 1.0), Vector2(-1.05, 3.05), Vector2(1.05, 3.05), Vector2(0.0, 5.1)]
	for k in cabinets.size():
		var c: Vector2 = cabinets[k]
		box(mb, Vector3(c.x, c.y, 0.0), Vector3(2.0, 2.0, 1.6), black, rng, 0.03)
		var center := Vector3(c.x, c.y, -0.83)
		var cone: Color = cones[k % 2]
		for i in 8:
			var a0 := TAU * i / 8.0
			var a1 := TAU * (i + 1) / 8.0
			mb.tri(center + Vector3(0, 0, -0.05), center + Vector3(cos(a0), sin(a0), 0.0) * 0.72, center + Vector3(cos(a1), sin(a1), 0.0) * 0.72, cone if i % 2 == 0 else shade(cone, 0.7), Vector3.FORWARD)
	return mb.build()


static func ruin(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var stone := Color(0.55, 0.53, 0.45)
	var y := 0.0
	var levels := rng.randi_range(3, 5)
	for k in levels:
		var h := rng.randf_range(1.2, 2.0)
		var w := rng.randf_range(1.6, 2.2) - k * 0.1
		var b := Basis(Vector3.UP, rng.randf_range(-0.15, 0.15))
		box(mb, Vector3(rng.randf_range(-0.1, 0.1), y + h * 0.5, 0.0), Vector3(w, h, w), stone, rng, 0.08, b)
		if k == 1:
			# glowing glyph on the face
			box(mb, Vector3(0.0, y + h * 0.5, -w * 0.5 - 0.02), Vector3(w * 0.4, h * 0.4, 0.05), glow(Color(0.2, 1.0, 0.85), 0.7))
		y += h
	blob(mb, Vector3(0.0, y + 0.1, 0.0), Vector3(1.2, 0.35, 1.2), rng, Color(0.27, 0.5, 0.18), 6, 2, 0.2)
	return mb.build()


static func arch(span: float, rng: RandomNumberGenerator, banner: Color) -> ArrayMesh:
	var mb := MB.new()
	var stone := Color(0.55, 0.52, 0.44)
	for sx: float in [-1.0, 1.0]:
		var y := -2.0
		for k in 5:
			box(mb, Vector3(sx * span * 0.5, y + 1.1, 0.0), Vector3(2.2, 2.2, 2.2), stone, rng, 0.1)
			y += 2.2
	box(mb, Vector3(0.0, 10.4, 0.0), Vector3(span + 3.4, 1.6, 2.4), stone, rng, 0.1)
	box(mb, Vector3(0.0, 8.4, 0.0), Vector3(span - 2.5, 2.2, 0.3), glow(banner, 0.55))
	for k in 6:
		var vx := rng.randf_range(-span * 0.5, span * 0.5)
		var vl := rng.randf_range(2.0, 4.5)
		mb.quad(Vector3(vx, 9.6, -1.25), Vector3(vx + 0.15, 9.6, -1.25), Vector3(vx + 0.12, 9.6 - vl, -1.3), Vector3(vx, 9.6 - vl, -1.3), Color(0.18, 0.42, 0.12), Vector3.FORWARD)
	return mb.build()


## Kicker ramp: starts just under the water at z=0 and rises to `h` at z=-length.
static func ramp(w: float, length: float, h: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var stone := Color(0.48, 0.44, 0.38)
	var moss := Color(0.32, 0.5, 0.22)
	var hw := w * 0.5
	var base := -2.0
	var p0l := Vector3(-hw, -0.35, 0.0)
	var p0r := Vector3(hw, -0.35, 0.0)
	var p1l := Vector3(-hw, h, -length)
	var p1r := Vector3(hw, h, -length)
	for k in 4:
		var t0 := k / 4.0
		var t1 := (k + 1) / 4.0
		mb.quad(p0l.lerp(p1l, t0), p0r.lerp(p1r, t0), p0r.lerp(p1r, t1), p0l.lerp(p1l, t1), vary(moss, rng, 0.05), Vector3.UP)
	var b0l := Vector3(-hw, base, 0.0)
	var b0r := Vector3(hw, base, 0.0)
	var b1l := Vector3(-hw, base, -length)
	var b1r := Vector3(hw, base, -length)
	mb.quad(b0l, p0l, p1l, b1l, stone, Vector3.LEFT)
	mb.quad(b0r, p0r, p1r, b1r, stone, Vector3.RIGHT)
	mb.quad(b1l, b1r, p1r, p1l, shade(stone, 0.8), Vector3.FORWARD)
	# glowing chevrons pointing up the ramp
	var chev := glow(Color(1.0, 0.7, 0.15), 0.7)
	var up_n := (p1l - p0l).cross(Vector3.RIGHT).normalized()
	if up_n.y < 0.0:
		up_n = -up_n
	for k in 3:
		var c := Vector3(0.0, -0.35, 0.0).lerp(Vector3(0.0, h, -length), 0.25 + 0.25 * k) + up_n * 0.06
		var fwd := (p1l - p0l).normalized()
		mb.tri(c - Vector3.RIGHT * hw * 0.5 - fwd * 0.4, c + Vector3.RIGHT * hw * 0.5 - fwd * 0.4, c + fwd * 0.6, chev, up_n)
	for sx: float in [-1.0, 1.0]:
		blob(mb, Vector3(sx * (hw + 0.6), 0.0, -length * 0.6), Vector3(1.0, 1.1, 1.4), rng, stone, 6, 3, 0.25)
	return mb.build()


static func ring(radius := 1.8, tube := 0.24) -> ArrayMesh:
	var mb := MB.new()
	var seg := 12
	var tseg := 4
	var gold := glow(Color(1.0, 0.78, 0.2), 0.55)
	var gold2 := glow(Color(1.0, 0.55, 0.15), 0.55)
	for i in seg:
		for j in tseg:
			var p := func(ii: int, jj: int) -> Vector3:
				var a := TAU * ii / seg
				var b := TAU * jj / tseg + PI / tseg
				var dir := Vector3(cos(a), sin(a), 0.0)
				return dir * radius + (dir * cos(b) + Vector3(0, 0, 1) * sin(b)) * tube
			var am := TAU * (i + 0.5) / seg
			var bm := TAU * (j + 0.5) / tseg + PI / tseg
			var dm := Vector3(cos(am), sin(am), 0.0)
			mb.quad(p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), gold if (i + j) % 2 == 0 else gold2, dm * cos(bm) + Vector3(0, 0, 1) * sin(bm))
	return mb.build()


static func bear_body(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var fur := Color(0.38, 0.23, 0.12)
	var tan := Color(0.64, 0.46, 0.3)
	var black := Color(0.05, 0.04, 0.04)
	for sx: float in [-1.0, 1.0]:
		frustum(mb, Vector3(sx * 0.45, -1.2, 0.0), Vector3(sx * 0.45, 0.7, 0.0), 0.34, 0.32, 5, fur)
	blob(mb, Vector3(0.0, 1.35, 0.0), Vector3(0.95, 1.1, 0.75), rng, fur, 7, 4, 0.08)
	blob(mb, Vector3(0.0, 1.2, -0.38), Vector3(0.6, 0.7, 0.42), rng, tan, 6, 3, 0.08)
	blob(mb, Vector3(0.0, 2.62, -0.1), Vector3(0.56, 0.5, 0.56), rng, fur, 6, 4, 0.08)
	blob(mb, Vector3(0.0, 2.5, -0.62), Vector3(0.26, 0.2, 0.3), rng, tan, 5, 3, 0.05)
	blob(mb, Vector3(0.0, 2.56, -0.9), Vector3(0.1, 0.08, 0.07), rng, black, 4, 2, 0.0)
	for sx: float in [-1.0, 1.0]:
		blob(mb, Vector3(sx * 0.38, 3.02, -0.05), Vector3(0.15, 0.15, 0.1), rng, fur, 5, 2, 0.05)
		box(mb, Vector3(sx * 0.2, 2.74, -0.55), Vector3(0.09, 0.09, 0.06), black)
	return mb.build()


static func bear_arm(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var fur := Color(0.36, 0.22, 0.11)
	frustum(mb, Vector3(0.0, 0.2, 0.0), Vector3(0.0, -1.15, 0.0), 0.3, 0.24, 5, fur)
	blob(mb, Vector3(0.0, -1.3, 0.0), Vector3(0.3, 0.24, 0.3), rng, fur, 5, 3, 0.05)
	var claw := Color(0.95, 0.92, 0.8)
	for k in 3:
		var x := -0.12 + 0.12 * k
		mb.tri(Vector3(x - 0.05, -1.4, -0.2), Vector3(x + 0.05, -1.4, -0.2), Vector3(x, -1.62, -0.3), claw, Vector3.FORWARD)
	return mb.build()
