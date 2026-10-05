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

## The sockeye at each stage of its life, youngest first. For each: the colours of its back,
## sides, belly, head, fins and jaw; how slim it is (1 is the full-grown fish); how big its
## head and eyes are for its body; how much of a hump and of a hooked jaw (kype) it has; whether
## it wears the dark bars of a parr; and how long it is beside a full-grown adult.
const SALMON_LOOKS := {
	"fry": {
		"back": Color(0.5, 0.46, 0.3), "side": Color(0.78, 0.74, 0.56), "belly": Color(0.95, 0.9, 0.78),
		"head": Color(0.56, 0.5, 0.34), "fin": Color(0.8, 0.76, 0.6), "jaw": Color(0.9, 0.86, 0.72),
		"slim": 0.62, "head_size": 1.45, "hump": 0.0, "kype": 0.0, "bars": 0, "size": 0.3,
	},
	"parr": {
		"back": Color(0.36, 0.38, 0.22), "side": Color(0.72, 0.7, 0.5), "belly": Color(0.95, 0.93, 0.84),
		"head": Color(0.4, 0.42, 0.26), "fin": Color(0.66, 0.6, 0.4), "jaw": Color(0.88, 0.86, 0.72),
		"slim": 0.76, "head_size": 1.2, "hump": 0.0, "kype": 0.0, "bars": 7, "size": 0.45,
	},
	"smolt": {
		"back": Color(0.22, 0.38, 0.44), "side": Color(0.8, 0.86, 0.88), "belly": Color(0.97, 0.98, 0.98),
		"head": Color(0.3, 0.44, 0.48), "fin": Color(0.5, 0.58, 0.62), "jaw": Color(0.88, 0.9, 0.86),
		"slim": 0.82, "head_size": 1.08, "hump": 0.0, "kype": 0.0, "bars": 0, "size": 0.7,
	},
	"ocean": {
		"back": Color(0.14, 0.28, 0.4), "side": Color(0.74, 0.8, 0.86), "belly": Color(0.96, 0.97, 0.98),
		"head": Color(0.22, 0.36, 0.46), "fin": Color(0.4, 0.48, 0.56), "jaw": Color(0.85, 0.88, 0.8),
		"slim": 1.0, "head_size": 1.0, "hump": 0.0, "kype": 0.0, "bars": 0, "size": 1.0,
	},
	"migrating": {
		"back": Color(0.4, 0.2, 0.24), "side": Color(0.84, 0.52, 0.5), "belly": Color(0.95, 0.82, 0.78),
		"head": Color(0.3, 0.42, 0.34), "fin": Color(0.5, 0.3, 0.3), "jaw": Color(0.85, 0.88, 0.76),
		"slim": 1.0, "head_size": 1.0, "hump": 0.35, "kype": 0.45, "bars": 0, "size": 1.0,
	},
	"spawner": {
		"back": Color(0.58, 0.07, 0.07), "side": Color(0.90, 0.14, 0.10), "belly": Color(0.98, 0.66, 0.52),
		"head": Color(0.30, 0.50, 0.20), "fin": Color(0.62, 0.10, 0.08), "jaw": Color(0.85, 0.88, 0.72),
		"slim": 1.0, "head_size": 1.0, "hump": 1.0, "kype": 1.0, "bars": 0, "size": 1.0,
	},
}


## How long the salmon is at a stage of its life, beside a full-grown adult (1).
static func salmon_size(look: String) -> float:
	return float(SALMON_LOOKS[look].size)


## A sockeye at one stage of its life: "fry", "parr", "smolt", "ocean", "migrating" or
## "spawner" (see SALMON_LOOKS). All are built to the same length; salmon_size() is how big
## each really is.
static func salmon(look := "spawner") -> ArrayMesh:
	var mb := MB.new()
	var L: Dictionary = SALMON_LOOKS[look]
	var slim: float = L.slim
	var big_head: float = L.head_size
	var hump: float = L.hump
	var kype: float = L.kype
	# z, half-width, half-height, y-centre (nose at -Z, which is Godot's forward)
	var rings := [
		[-1.20, 0.03, 0.03, -0.02],
		[-0.95, 0.17 * big_head, 0.21 * big_head, 0.00],
		[-0.55, 0.26, 0.37 + 0.08 * hump, 0.05 + 0.07 * hump],
		[-0.10, 0.28, 0.42 + 0.05 * hump, 0.07 + 0.04 * hump],
		[0.35, 0.22, 0.30, 0.03],
		[0.72, 0.11, 0.15, 0.00],
		[0.92, 0.05, 0.08, 0.00],
	]
	for ring: Array in rings:
		ring[1] *= slim
		ring[2] *= slim
	var back: Color = L.back
	var side: Color = L.side
	var belly: Color = L.belly
	var head: Color = L.head
	var jaw: Color = L.jaw
	var fin: Color = L.fin
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
			var col := head if zmid < -0.6 else side
			if sn > 0.6 and zmid >= -0.6:
				col = back
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
		mb.tri(tip, Vector3(cos(a0) * 0.03, -0.02 + sin(a0) * 0.03, -1.2), Vector3(cos(a1) * 0.03, -0.02 + sin(a1) * 0.03, -1.2), head, Vector3.FORWARD)
		mb.tri(tail_end, Vector3(cos(a0) * 0.05 * slim, sin(a0) * 0.08 * slim, 0.92), Vector3(cos(a1) * 0.05 * slim, sin(a1) * 0.08 * slim, 0.92), back, Vector3.BACK)
	# forked tail (smaller on the young)
	var tail := lerpf(0.7, 1.0, slim)
	var t0 := Vector3(0.0, 0.08 * slim, 0.9)
	var t1 := Vector3(0.0, -0.08 * slim, 0.9)
	var notch := Vector3(0.0, 0.0, 1.16)
	mb.tri(t0, Vector3(0.0, 0.52 * tail, 1.42), notch, fin, Vector3.RIGHT)
	mb.tri(t1, notch, Vector3(0.0, -0.46 * tail, 1.40), fin, Vector3.RIGHT)
	mb.tri(t0, notch, t1, fin, Vector3.RIGHT)
	# dorsal, adipose, anal fins
	# (each one is rooted inside the body, so none of them floats clear of it)
	var top := 0.32 * slim + 0.1 * hump
	mb.tri(Vector3(0.0, top, -0.44), Vector3(0.0, top + 0.52 * tail, -0.10), Vector3(0.0, top, 0.22), back, Vector3.RIGHT)
	mb.tri(Vector3(0.0, top + 0.52 * tail, -0.10), Vector3(0.0, top + 0.3 * tail, 0.20), Vector3(0.0, top, 0.22), back, Vector3.RIGHT)
	mb.tri(Vector3(0.0, 0.14 * slim, 0.50), Vector3(0.0, 0.14 * slim + 0.26 * tail, 0.70), Vector3(0.0, 0.08 * slim, 0.74), back, Vector3.RIGHT)
	mb.tri(Vector3(0.0, -0.14 * slim, 0.42), Vector3(0.0, -0.14 * slim - 0.32 * tail, 0.64), Vector3(0.0, -0.06 * slim, 0.72), fin, Vector3.RIGHT)
	# kype (the hooked jaw males grow for the spawning run)
	if kype > 0.0:
		mb.tri(Vector3(0.0, -0.04, -1.18), Vector3(0.0, -0.04 - 0.12 * kype, -1.18 - 0.12 * kype), Vector3(0.0, -0.12, -1.02), jaw, Vector3.RIGHT)
	# parr marks: dark upright bars along each flank
	var bars: int = L.bars
	for k in bars:
		var z := lerpf(-0.6, 0.66, float(k) / maxf(bars - 1.0, 1.0))
		# (how wide and tall the body is there, from the rings either side)
		var hw := 0.0
		var hh := 0.0
		var yc := 0.0
		for r in rings.size() - 1:
			if z >= float(rings[r][0]) and z <= float(rings[r + 1][0]):
				var t := (z - float(rings[r][0])) / (float(rings[r + 1][0]) - float(rings[r][0]))
				hw = lerpf(rings[r][1], rings[r + 1][1], t)
				hh = lerpf(rings[r][2], rings[r + 1][2], t)
				yc = lerpf(rings[r][3], rings[r + 1][3], t)
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hw * 0.93 + 0.012), yc, z)
			var up := Vector3(0.0, hh * 0.5, 0.0)
			var along := Vector3(0.0, 0.0, 0.045)
			mb.quad(c + up - along, c + up + along, c - up + along, c - up - along, back.darkened(0.25), Vector3(sx, 0, 0))
	for sx: float in [-1.0, 1.0]:
		# pectoral + pelvic fins
		mb.tri(Vector3(sx * 0.16 * slim, -0.16 * slim, -0.56), Vector3(sx * (0.16 * slim + 0.46 * tail), -0.16 * slim - 0.24 * tail, -0.28), Vector3(sx * 0.16 * slim, -0.24 * slim, -0.25), fin, Vector3.UP)
		mb.tri(Vector3(sx * 0.1 * slim, -0.22 * slim, 0.2), Vector3(sx * (0.1 * slim + 0.24 * tail), -0.22 * slim - 0.28 * tail, 0.42), Vector3(sx * 0.08 * slim, -0.2 * slim, 0.42), fin, Vector3.UP)
		# eye (big, on the young)
		var e := Vector3(sx * (0.205 * slim * lerpf(1.0, big_head, 0.8) + 0.002), 0.1 * slim, -0.82)
		var es := lerpf(1.0, big_head, 1.2) * lerpf(0.85, 1.0, slim)
		mb.quad(e + Vector3(0, 0.07, -0.06) * es, e + Vector3(0, 0.07, 0.06) * es, e + Vector3(0, -0.06, 0.06) * es, e + Vector3(0, -0.06, -0.06) * es, Color(0.95, 0.85, 0.3), Vector3(sx, 0, 0))
		var p := e + Vector3(sx * 0.005, 0.0, 0.0)
		mb.quad(p + Vector3(0, 0.04, -0.03) * es, p + Vector3(0, 0.04, 0.03) * es, p + Vector3(0, -0.03, 0.03) * es, p + Vector3(0, -0.03, -0.03) * es, Color(0.02, 0.02, 0.02), Vector3(sx, 0, 0))
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


static func rock(rng: RandomNumberGenerator, col := Color(0.46, 0.44, 0.40), cap := Color(0.28, 0.48, 0.18)) -> ArrayMesh:
	var mb := MB.new()
	blob(mb, Vector3(0.0, 0.2, 0.0), Vector3(1.0, 0.75, 1.0), rng, col, 6, 3, 0.28, 0.05)
	# a little cap of moss (or snow, or coral)
	blob(mb, Vector3(0.0, 0.75, 0.0), Vector3(0.6, 0.18, 0.6), rng, cap, 5, 2, 0.2)
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


static func hill(rng: RandomNumberGenerator, col := Color(0.08, 0.26, 0.14)) -> ArrayMesh:
	var mb := MB.new()
	var r := rng.randf_range(35.0, 65.0)
	blob(mb, Vector3.ZERO, Vector3(r, r * rng.randf_range(0.6, 1.1), r), rng, col, 9, 4, 0.18, 0.04)
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


static func arch(span: float, rng: RandomNumberGenerator, banner: Color, stone := Color(0.55, 0.52, 0.44)) -> ArrayMesh:
	var mb := MB.new()
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
static func ramp(w: float, length: float, h: float, rng: RandomNumberGenerator,
		stone := Color(0.48, 0.44, 0.38), moss := Color(0.32, 0.5, 0.22)) -> ArrayMesh:
	var mb := MB.new()
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


static func ring(radius := 1.8, tube := 0.24, colour := Color(1.0, 0.78, 0.2), colour2 := Color(1.0, 0.55, 0.15)) -> ArrayMesh:
	var mb := MB.new()
	var seg := 12
	var tseg := 4
	var gold := glow(colour, 0.55)
	var gold2 := glow(colour2, 0.55)
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


# ------------------------------------------------------------------ ocean, coast and mountains

static func buoy(rng: RandomNumberGenerator, body: Color, light: Color) -> ArrayMesh:
	var mb := MB.new()
	blob(mb, Vector3(0.0, 0.0, 0.0), Vector3(0.6, 0.35, 0.6), rng, shade(body, 0.7), 6, 2, 0.05)
	frustum(mb, Vector3(0.0, 0.1, 0.0), Vector3(0.0, 1.0, 0.0), 0.45, 0.28, 6, body, false)
	frustum(mb, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.7, 0.0), 0.28, 0.12, 6, Color(0.95, 0.95, 0.9), false)
	blob(mb, Vector3(0.0, 1.9, 0.0), Vector3(0.24, 0.24, 0.24), rng, glow(light, 0.85), 5, 3, 0.0)
	return mb.build()


static func iceberg(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var ice := Color(0.8, 0.92, 1.0)
	for k in rng.randi_range(2, 3):
		var c := Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.5, 2.0), rng.randf_range(-3.0, 3.0))
		blob(mb, c, Vector3(rng.randf_range(3.0, 5.0), rng.randf_range(3.5, 7.0), rng.randf_range(3.0, 5.0)), rng,
				ice.lerp(Color(0.55, 0.8, 0.95), rng.randf() * 0.5), 6, 3, 0.35, 0.03)
	return mb.build()


static func floe(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	blob(mb, Vector3(0.0, 0.05, 0.0), Vector3(rng.randf_range(1.6, 3.2), 0.3, rng.randf_range(1.6, 3.2)), rng,
			Color(0.9, 0.96, 1.0), 6, 2, 0.3, 0.03)
	return mb.build()


static func coral(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var cols := [Color(1.0, 0.4, 0.55), Color(1.0, 0.62, 0.25), Color(0.7, 0.4, 1.0), Color(0.3, 0.9, 0.8)]
	var col: Color = cols[rng.randi() % cols.size()]
	blob(mb, Vector3(0.0, 0.3, 0.0), Vector3(0.9, 0.6, 0.9), rng, shade(col, 0.7), 6, 3, 0.25)
	for k in rng.randi_range(3, 6):
		var a := rng.randf() * TAU
		var tip := Vector3(cos(a) * rng.randf_range(0.4, 1.2), rng.randf_range(1.2, 2.4), sin(a) * rng.randf_range(0.4, 1.2))
		frustum(mb, Vector3(cos(a), 0.0, sin(a)) * 0.3 + Vector3(0.0, 0.5, 0.0), tip, 0.22, 0.12, 4, col, true, rng)
		blob(mb, tip, Vector3(0.2, 0.2, 0.2), rng, glow(col, 0.4), 4, 2, 0.1)
	return mb.build()


## A rock pillar standing in the sea.
static func sea_stack(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var stone := Color(0.62, 0.55, 0.44)
	var y := -1.0
	var w := rng.randf_range(3.0, 4.5)
	for k in rng.randi_range(3, 5):
		var h := rng.randf_range(2.0, 3.5)
		box(mb, Vector3(rng.randf_range(-0.4, 0.4), y + h * 0.5, rng.randf_range(-0.4, 0.4)), Vector3(w, h, w), stone, rng, 0.35,
				Basis(Vector3.UP, rng.randf() * TAU))
		y += h
		w *= rng.randf_range(0.7, 0.9)
	blob(mb, Vector3(0.0, y, 0.0), Vector3(w * 0.7, 0.5, w * 0.7), rng, Color(0.3, 0.52, 0.22), 6, 2, 0.2)
	return mb.build()


static func grass(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	for k in rng.randi_range(7, 11):
		var o := Vector3(rng.randf_range(-0.8, 0.8), -0.2, rng.randf_range(-0.8, 0.8))
		var h := rng.randf_range(0.8, 1.7)
		var lean := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var col := Color(0.62, 0.66, 0.3).lerp(Color(0.42, 0.56, 0.24), rng.randf())
		mb.tri(o, o + Vector3(0.14, 0.0, 0.0), o + lean + Vector3(0.05, h, 0.0), col, Vector3.BACK)
	return mb.build()


static func umbrella(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var cols := [Color(1.0, 0.3, 0.45), Color(0.2, 0.8, 0.9), Color(1.0, 0.75, 0.2)]
	var col: Color = cols[rng.randi() % cols.size()]
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
	var top := Vector3(0.0, 2.4, 0.0) + lean
	frustum(mb, Vector3(0.0, -0.3, 0.0), top, 0.06, 0.05, 4, Color(0.9, 0.9, 0.85), false)
	for k in 8:
		var a0 := TAU * k / 8.0
		var a1 := TAU * (k + 1) / 8.0
		mb.tri(top + Vector3(0.0, 0.25, 0.0), top + Vector3(cos(a0) * 1.5, -0.35, sin(a0) * 1.5),
				top + Vector3(cos(a1) * 1.5, -0.35, sin(a1) * 1.5), col if k % 2 == 0 else Color(0.97, 0.97, 0.92), Vector3.UP)
	# towel
	box(mb, Vector3(1.4, -0.02, 0.4), Vector3(0.9, 0.06, 1.9), col, null, 0.0, Basis(Vector3.UP, rng.randf() * TAU))
	return mb.build()


static func driftwood(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var wood := Color(0.66, 0.6, 0.52)
	var a := rng.randf() * TAU
	var d := Vector3(cos(a), 0.08, sin(a)) * rng.randf_range(1.5, 2.8)
	frustum(mb, -d, d, 0.28, 0.16, 5, wood, true, rng)
	frustum(mb, d * 0.2, d * 0.2 + Vector3(-d.z, 2.0, d.x) * 0.35, 0.12, 0.05, 4, shade(wood, 0.85), true)
	return mb.build()


## snow: the chance it carries snow. gold: a larch in its autumn colours.
static func pine(rng: RandomNumberGenerator, snow := 0.0, gold := false) -> ArrayMesh:
	var mb := MB.new()
	var h := rng.randf_range(8.0, 14.0)
	frustum(mb, Vector3(0.0, -0.8, 0.0), Vector3(0.0, h * 0.4, 0.0), 0.4, 0.28, 5, Color(0.3, 0.2, 0.13), false, rng)
	var green := Color(0.09, 0.28, 0.2).lerp(Color(0.16, 0.4, 0.24), rng.randf())
	if gold:
		green = Color(0.9, 0.62, 0.12).lerp(Color(0.8, 0.42, 0.1), rng.randf())
	var snowy := rng.randf() < snow
	for k in 4:
		var y0 := h * (0.2 + 0.2 * k)
		var r := lerpf(3.1, 1.2, k / 3.0) * rng.randf_range(0.9, 1.1)
		frustum(mb, Vector3(0.0, y0, 0.0), Vector3(0.0, y0 + h * 0.3, 0.0), r, 0.05, 6, green, false, rng)
		if snowy:
			frustum(mb, Vector3(0.0, y0 + h * 0.16, 0.0), Vector3(0.0, y0 + h * 0.31, 0.0), r * 0.52, 0.05, 6, Color(0.93, 0.96, 1.0), false)
	return mb.build()


## A far-off snow-capped peak.
static func mountain(rng: RandomNumberGenerator, stone: Color, cap := Color(0.94, 0.96, 1.0)) -> ArrayMesh:
	var mb := MB.new()
	var r := rng.randf_range(45.0, 80.0)
	var h := r * rng.randf_range(1.0, 1.5)
	var lean := Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15)) * r
	frustum(mb, Vector3(0.0, -20.0, 0.0), Vector3(0.0, h * 0.58, 0.0) + lean * 0.6, r * 1.3, r * 0.42, 7, stone, false, rng)
	frustum(mb, Vector3(0.0, h * 0.58, 0.0) + lean * 0.6, Vector3(0.0, h, 0.0) + lean, r * 0.42, 0.5, 7, cap, false, rng)
	return mb.build()


## Modelled nose-up, mouth towards -Z: it lunges straight up out of the water.
static func shark_body(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var grey := Color(0.36, 0.44, 0.52)
	var white := Color(0.93, 0.95, 0.95)
	frustum(mb, Vector3(0.0, -1.4, 0.0), Vector3(0.0, 1.2, 0.0), 0.6, 0.85, 6, grey, false, rng)
	frustum(mb, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 2.4, 0.0), 0.85, 0.62, 6, grey, false, rng)
	frustum(mb, Vector3(0.0, 2.4, 0.0), Vector3(0.0, 3.3, -0.2), 0.62, 0.08, 6, grey, true, rng)
	# belly, open mouth and teeth
	box(mb, Vector3(0.0, 0.8, -0.72), Vector3(0.9, 2.6, 0.25), white)
	box(mb, Vector3(0.0, 2.25, -0.62), Vector3(0.95, 0.55, 0.3), Color(0.55, 0.05, 0.1))
	for k in 5:
		var x := -0.36 + 0.18 * k
		mb.tri(Vector3(x - 0.08, 2.52, -0.8), Vector3(x + 0.08, 2.52, -0.8), Vector3(x, 2.3, -0.84), white, Vector3.FORWARD)
		mb.tri(Vector3(x - 0.08, 1.98, -0.8), Vector3(x + 0.08, 1.98, -0.8), Vector3(x, 2.2, -0.84), white, Vector3.FORWARD)
	for sx: float in [-1.0, 1.0]:
		box(mb, Vector3(sx * 0.5, 2.75, -0.3), Vector3(0.1, 0.12, 0.1), Color(0.02, 0.02, 0.02))
		mb.tri(Vector3(sx * 0.7, 1.3, 0.0), Vector3(sx * 1.9, 0.5, 0.1), Vector3(sx * 0.7, 0.5, 0.0), grey, Vector3.FORWARD)
	mb.tri(Vector3(0.0, 1.6, 0.8), Vector3(0.0, 0.3, 1.9), Vector3(0.0, 0.5, 0.75), grey, Vector3.RIGHT)
	return mb.build()


static func shark_fin() -> ArrayMesh:
	var mb := MB.new()
	mb.tri(Vector3(0.0, -0.3, -0.7), Vector3(0.0, 1.3, 0.35), Vector3(0.0, -0.3, 0.7), Color(0.36, 0.44, 0.52), Vector3.RIGHT)
	return mb.build()


# ------------------------------------------------------------------ the man-made route

const CONTAINER_COLORS := [Color(0.75, 0.3, 0.15), Color(0.2, 0.45, 0.75), Color(0.85, 0.7, 0.2),
		Color(0.25, 0.55, 0.35), Color(0.6, 0.6, 0.62)]


## A shipping container (or, tinted, a barrel of feed): the man-made levels' answer to a rock.
static func crate(rng: RandomNumberGenerator, col: Color) -> ArrayMesh:
	var mb := MB.new()
	var b := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
	box(mb, Vector3(0.0, 0.3, 0.0), Vector3(1.9, 1.4, 1.5), col, rng, 0.03, b)
	box(mb, Vector3(0.0, 0.3, 0.0), Vector3(1.94, 0.12, 1.54), shade(col, 0.6), null, 0.0, b)
	return mb.build()


static func ship(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	box(mb, b * Vector3(0.0, 3.0, 0.0), Vector3(14.0, 9.0, 70.0), Color(0.16, 0.17, 0.2), rng, 0.3, b)
	box(mb, b * Vector3(0.0, -0.5, 0.0), Vector3(14.2, 2.0, 70.2), Color(0.5, 0.12, 0.1), null, 0.0, b)
	box(mb, b * Vector3(0.0, 13.0, 27.0), Vector3(11.0, 11.0, 9.0), Color(0.9, 0.9, 0.86), rng, 0.1, b)
	box(mb, b * Vector3(0.0, 18.2, 22.4), Vector3(9.0, 1.2, 0.3), glow(Color(1.0, 0.85, 0.5), 0.7), null, 0.0, b)
	for row in 5:
		for stack in 2:
			var h := rng.randi_range(1, 3) * 2.6
			var col: Color = CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()]
			box(mb, b * Vector3(-3.3 + stack * 6.6, 7.5 + h * 0.5, -28.0 + row * 10.0), Vector3(6.0, h, 9.0), col, rng, 0.05, b)
	return mb.build()


static func piling(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var wood := Color(0.3, 0.22, 0.16)
	for k in rng.randi_range(1, 3):
		var o := Vector3(rng.randf_range(-0.5, 0.5), -1.5, rng.randf_range(-0.5, 0.5))
		var h := rng.randf_range(2.6, 4.0)
		frustum(mb, o, o + Vector3(rng.randf_range(-0.15, 0.15), h + 1.5, 0.0), 0.24, 0.2, 5, wood, true, rng)
	return mb.build()


## A dockside gantry crane.
static func crane(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var paint: Color = [Color(0.9, 0.45, 0.1), Color(0.8, 0.2, 0.15), Color(0.2, 0.45, 0.7)][rng.randi() % 3]
	var b := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(mb, b * Vector3(sx * 5.0, 11.0, sz * 4.0), Vector3(1.0, 22.0, 1.0), paint, rng, 0.05, b)
		box(mb, b * Vector3(sx * 5.0, 12.0, 0.0), Vector3(0.8, 0.8, 8.0), shade(paint, 0.8), null, 0.0, b)
	box(mb, b * Vector3(0.0, 22.5, 0.0), Vector3(34.0, 1.6, 3.0), paint, rng, 0.05, b)
	box(mb, b * Vector3(-4.0, 20.6, 0.0), Vector3(3.0, 2.4, 3.0), Color(0.85, 0.85, 0.8), null, 0.0, b)
	box(mb, b * Vector3(-15.0, 23.8, 0.0), Vector3(0.6, 0.6, 0.6), glow(Color(1.0, 0.2, 0.2), 0.9), null, 0.0, b)
	return mb.build()


## A tin shed with lit windows.
static func shed(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var col: Color = [Color(0.45, 0.5, 0.55), Color(0.55, 0.4, 0.32), Color(0.35, 0.48, 0.42)][rng.randi() % 3]
	var w := rng.randf_range(5.0, 9.0)
	var d := rng.randf_range(4.0, 7.0)
	var h := rng.randf_range(3.0, 4.5)
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	box(mb, b * Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), col, rng, 0.05, b)
	box(mb, b * Vector3(0.0, h + 0.2, 0.0), Vector3(w + 0.6, 0.4, d + 0.6), shade(col, 0.6), null, 0.0, b)
	for k in 3:
		box(mb, b * Vector3(-w * 0.3 + k * w * 0.3, h * 0.6, -d * 0.5 - 0.03), Vector3(0.9, 0.8, 0.06), glow(Color(1.0, 0.85, 0.45), 0.7), null, 0.0, b)
	return mb.build()


static func lamp(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var steel := Color(0.3, 0.32, 0.36)
	var h := rng.randf_range(5.0, 6.5)
	frustum(mb, Vector3(0.0, -0.3, 0.0), Vector3(0.0, h, 0.0), 0.12, 0.08, 4, steel, false)
	box(mb, Vector3(0.5, h, 0.0), Vector3(1.2, 0.12, 0.12), steel)
	box(mb, Vector3(1.0, h - 0.15, 0.0), Vector3(0.5, 0.18, 0.3), glow(Color(1.0, 0.72, 0.3), 0.9))
	return mb.build()


## A fish-farm net pen: a ring of floats with a handrail.
static func pen(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var r := rng.randf_range(4.5, 6.5)
	var n := 12
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * r
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * r
		frustum(mb, p0 + Vector3(0.0, 0.1, 0.0), p1 + Vector3(0.0, 0.1, 0.0), 0.3, 0.3, 5, Color(0.12, 0.12, 0.14), false)
		frustum(mb, p0, p0 + Vector3(0.0, 1.3, 0.0), 0.06, 0.06, 4, Color(0.8, 0.8, 0.78), false)
		frustum(mb, p0 + Vector3(0.0, 1.3, 0.0), p1 + Vector3(0.0, 1.3, 0.0), 0.05, 0.05, 4, Color(0.9, 0.75, 0.2), false)
	return mb.build()


# ------------------------------------------------------------------ trench, plains and desert

## A glowing jellyfish drifting at the surface.
static func jelly(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var col: Color = [Color(0.3, 1.0, 0.9), Color(0.7, 0.4, 1.0), Color(1.0, 0.4, 0.8)][rng.randi() % 3]
	blob(mb, Vector3(0.0, 0.25, 0.0), Vector3(0.7, 0.45, 0.7), rng, glow(col, 0.75), 6, 3, 0.1)
	for k in 5:
		var a := TAU * k / 5.0
		var o := Vector3(cos(a), 0.0, sin(a)) * 0.35
		mb.tri(o + Vector3(-0.06, 0.1, 0.0), o + Vector3(0.06, 0.1, 0.0), o * 1.5 + Vector3(0.0, -1.3, 0.0), glow(col, 0.5), o)
	return mb.build()


## A jagged seamount breaking the surface, with something glowing on it.
static func spire(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var stone := Color(0.14, 0.12, 0.22)
	for k in rng.randi_range(2, 4):
		var o := Vector3(rng.randf_range(-2.5, 2.5), -1.0, rng.randf_range(-2.5, 2.5))
		var h := rng.randf_range(5.0, 12.0)
		var tip := o + Vector3(rng.randf_range(-1.0, 1.0), h, rng.randf_range(-1.0, 1.0))
		frustum(mb, o, tip, rng.randf_range(1.6, 2.6), 0.15, 5, stone, false, rng)
		blob(mb, o.lerp(tip, rng.randf_range(0.3, 0.7)), Vector3(0.3, 0.3, 0.3), rng, glow(Color(0.3, 1.0, 0.9), 0.85), 4, 2, 0.1)
	return mb.build()


static func bale(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var a := rng.randf() * TAU
	var d := Vector3(cos(a), 0.0, sin(a)) * 0.9
	frustum(mb, Vector3(0.0, 0.8, 0.0) - d, Vector3(0.0, 0.8, 0.0) + d, 0.85, 0.85, 8, Color(0.84, 0.7, 0.3), true, rng)
	return mb.build()


static func barn(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var red := Color(0.62, 0.16, 0.12)
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	box(mb, b * Vector3(0.0, 2.5, 0.0), Vector3(8.0, 5.0, 11.0), red, rng, 0.05, b)
	var roof := Color(0.3, 0.3, 0.34)
	for sx: float in [-1.0, 1.0]:
		mb.quad(b * Vector3(sx * 4.4, 4.8, -5.8), b * Vector3(sx * 4.4, 4.8, 5.8), b * Vector3(0.0, 8.2, 5.8), b * Vector3(0.0, 8.2, -5.8), roof, b * Vector3(sx, 1.0, 0.0))
	for sz: float in [-1.0, 1.0]:
		mb.tri(b * Vector3(-4.0, 5.0, sz * 5.5), b * Vector3(4.0, 5.0, sz * 5.5), b * Vector3(0.0, 8.2, sz * 5.5), red, b * Vector3(0.0, 0.0, sz))
	box(mb, b * Vector3(0.0, 1.6, -5.55), Vector3(3.0, 3.2, 0.1), Color(0.95, 0.93, 0.88), null, 0.0, b)
	return mb.build()


static func windmill(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var steel := Color(0.7, 0.72, 0.74)
	var h := rng.randf_range(11.0, 14.0)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		frustum(mb, Vector3(cos(a), 0.0, sin(a)) * 1.6 + Vector3(0.0, -0.4, 0.0), Vector3(cos(a), 0.0, sin(a)) * 0.3 + Vector3(0.0, h, 0.0), 0.08, 0.06, 4, steel, false)
	var hub := Vector3(0.0, h, -0.5)
	var spin := rng.randf() * TAU
	for k in 12:
		var a0 := spin + TAU * k / 12.0
		var a1 := a0 + TAU / 20.0
		mb.tri(hub, hub + Vector3(cos(a0), sin(a0), 0.0) * 2.6, hub + Vector3(cos(a1), sin(a1), 0.0) * 2.6, Color(0.9, 0.9, 0.88), Vector3.FORWARD)
	mb.tri(hub + Vector3(0.0, 0.0, 0.6), hub + Vector3(0.0, 0.9, 2.6), hub + Vector3(0.0, -0.9, 2.6), Color(0.75, 0.2, 0.15), Vector3.RIGHT)
	return mb.build()


static func cactus(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var green := Color(0.3, 0.52, 0.3).lerp(Color(0.4, 0.58, 0.3), rng.randf())
	var h := rng.randf_range(3.0, 5.5)
	frustum(mb, Vector3(0.0, -0.3, 0.0), Vector3(0.0, h, 0.0), 0.42, 0.36, 6, green, true, rng)
	for k in rng.randi_range(0, 3):
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		var y := rng.randf_range(h * 0.3, h * 0.6)
		var elbow := Vector3(0.0, y, 0.0) + d * 1.0
		frustum(mb, Vector3(0.0, y, 0.0), elbow, 0.26, 0.24, 5, green, false, rng)
		frustum(mb, elbow, elbow + Vector3(0.0, rng.randf_range(1.0, 2.0), 0.0), 0.24, 0.2, 5, green, true, rng)
	return mb.build()


## A flat-topped butte on the horizon.
static func mesa(rng: RandomNumberGenerator, stone: Color) -> ArrayMesh:
	var mb := MB.new()
	var r := rng.randf_range(22.0, 40.0)
	var h := rng.randf_range(28.0, 46.0)
	frustum(mb, Vector3(0.0, -15.0, 0.0), Vector3(0.0, h * 0.45, 0.0), r * 1.7, r * 1.05, 8, shade(stone, 0.85), false, rng)
	frustum(mb, Vector3(0.0, h * 0.45, 0.0), Vector3(0.0, h, 0.0), r, r * 0.9, 8, stone, true, rng)
	return mb.build()


# ------------------------------------------------------------------ the bamboo river

## A clump of bamboo: tall jointed canes with leaves at the top.
static func bamboo(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	for k in rng.randi_range(4, 7):
		var o := Vector3(rng.randf_range(-1.0, 1.0), -0.4, rng.randf_range(-1.0, 1.0))
		var h := rng.randf_range(7.0, 12.0)
		var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 0.9
		var cane := Color(0.5, 0.68, 0.24).lerp(Color(0.4, 0.58, 0.2), rng.randf())
		var prev := o
		for j in 4:
			var t := float(j + 1) / 4.0
			var p := o + Vector3(0.0, h * t, 0.0) + lean * t * t
			frustum(mb, prev, p, 0.11, 0.1, 4, cane if j % 2 == 0 else shade(cane, 0.85), false)
			prev = p
		for j in 5:
			var a := rng.randf() * TAU
			blade(mb, prev - Vector3(0.0, rng.randf_range(0.0, h * 0.35), 0.0), Vector3(cos(a), 0.0, sin(a)),
					rng.randf_range(1.2, 2.2), 0.3, 0.3, 0.9, Color(0.3, 0.6, 0.2), rng, 2)
	return mb.build()


## A maple (or, in pink, a cherry in blossom): a dark trunk under clouds of leaves.
static func maple(rng: RandomNumberGenerator, leaf: Color, leaf2: Color) -> ArrayMesh:
	var mb := MB.new()
	var bark := Color(0.24, 0.17, 0.14)
	var h := rng.randf_range(3.5, 5.5)
	var top := Vector3(rng.randf_range(-0.8, 0.8), h, rng.randf_range(-0.8, 0.8))
	frustum(mb, Vector3(0.0, -0.5, 0.0), top, 0.34, 0.2, 5, bark, false, rng)
	for k in rng.randi_range(3, 5):
		var off := Vector3(rng.randf_range(-2.2, 2.2), rng.randf_range(-0.3, 1.4), rng.randf_range(-2.2, 2.2))
		frustum(mb, top, top + off * 0.8, 0.12, 0.06, 4, bark, false)
		blob(mb, top + off, Vector3(rng.randf_range(1.6, 2.4), rng.randf_range(0.9, 1.3), rng.randf_range(1.6, 2.4)), rng,
				leaf.lerp(leaf2, rng.randf()), 6, 3, 0.25)
	return mb.build()


static func torii(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var red := Color(0.82, 0.16, 0.1)
	var b := Basis(Vector3.UP, rng.randf_range(-0.4, 0.4))
	for sx: float in [-1.0, 1.0]:
		frustum(mb, b * Vector3(sx * 2.0, -0.4, 0.0), b * Vector3(sx * 1.8, 5.0, 0.0), 0.26, 0.22, 6, red, false)
		box(mb, b * Vector3(sx * 2.0, 0.0, 0.0), Vector3(0.7, 0.5, 0.7), Color(0.12, 0.1, 0.1), null, 0.0, b)
	box(mb, b * Vector3(0.0, 4.2, 0.0), Vector3(4.6, 0.32, 0.3), red, null, 0.0, b)
	box(mb, b * Vector3(0.0, 5.2, 0.0), Vector3(5.6, 0.4, 0.45), red, null, 0.0, b)
	box(mb, b * Vector3(0.0, 5.55, 0.0), Vector3(6.2, 0.26, 0.6), Color(0.12, 0.1, 0.1), null, 0.0, b)
	return mb.build()


## A stone lantern with a lit window.
static func lantern(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var stone := Color(0.56, 0.56, 0.52)
	box(mb, Vector3(0.0, 0.1, 0.0), Vector3(0.9, 0.3, 0.9), stone, rng, 0.03)
	frustum(mb, Vector3(0.0, 0.2, 0.0), Vector3(0.0, 1.3, 0.0), 0.2, 0.16, 5, stone, false)
	box(mb, Vector3(0.0, 1.4, 0.0), Vector3(0.8, 0.14, 0.8), stone)
	box(mb, Vector3(0.0, 1.75, 0.0), Vector3(0.5, 0.5, 0.5), glow(Color(1.0, 0.7, 0.3), 0.85))
	frustum(mb, Vector3(0.0, 2.0, 0.0), Vector3(0.0, 2.5, 0.0), 0.66, 0.06, 4, stone, false)
	return mb.build()


# ------------------------------------------------------------------ splashes

const WATER_WHITE := Color(0.96, 1.0, 1.0)
const WATER_BLUE := Color(0.62, 0.9, 0.98)


## A ring of `count` columns of water round a circle of radius 1, each 1 high and leaning out a
## little, for a landing splash (the node is scaled to size). `thick` is their width, as a
## share of the radius of the ring.
static func splash_columns(count: int, thick: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	for i in count:
		var a := TAU * (i + rng.randf_range(-0.25, 0.25)) / count
		var out := Vector3(cos(a), 0.0, sin(a))
		var h := rng.randf_range(0.65, 1.0)
		var base := out * rng.randf_range(0.92, 1.08)
		var mid := base + out * 0.12 + Vector3(0.0, h * 0.6, 0.0)
		var tip := base + out * 0.3 + Vector3(0.0, h, 0.0)
		frustum(mb, base + Vector3(0.0, -0.05, 0.0), mid, thick, thick * 0.8, 5, WATER_BLUE, false)
		frustum(mb, mid, tip, thick * 0.8, thick * 0.12, 5, WATER_WHITE, true)
	return mb.build()


## A flat ring lying on the water (outer radius 1), for the ripples that spread from a splash.
static func splash_ring() -> ArrayMesh:
	var mb := MB.new()
	var seg := 20
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		mb.quad(d0 * 0.84, d1 * 0.84, d1, d0, WATER_WHITE, Vector3.UP)
	return mb.build()


## A drop of water: round, a little lumpy, never square.
static func droplet(rng: RandomNumberGenerator, lumpy := 0.25) -> ArrayMesh:
	var mb := MB.new()
	blob(mb, Vector3.ZERO, Vector3(0.5, 0.5, 0.5), rng, WATER_WHITE, 6, 4, lumpy, 0.02)
	return mb.build()


## A splat: a drop flung flat, with a tail.
static func splat(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	blob(mb, Vector3.ZERO, Vector3(0.5, 0.3, 0.42), rng, WATER_WHITE, 6, 3, 0.3, 0.02)
	blob(mb, Vector3(-0.5, 0.05, 0.0), Vector3(0.28, 0.16, 0.2), rng, WATER_BLUE, 5, 3, 0.3, 0.02)
	blob(mb, Vector3(-0.85, 0.1, 0.05), Vector3(0.13, 0.1, 0.1), rng, WATER_WHITE, 4, 2, 0.2, 0.02)
	return mb.build()


## A sea nettle: an amber bell with dark stripes down it, frilly pale arms under the middle
## and long thin tentacles trailing from the rim.
static func sea_nettle(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var amber := glow(Color(1.0, 0.62, 0.22), 0.45)
	var stripe := glow(Color(0.62, 0.2, 0.1), 0.3)
	var pale := glow(Color(1.0, 0.9, 0.78), 0.5)
	blob(mb, Vector3(0.0, 0.2, 0.0), Vector3(0.85, 0.6, 0.85), rng, amber, 8, 4, 0.04)
	for k in 8:
		var a := TAU * k / 8.0
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		# a stripe from the crown to the rim
		mb.tri(Vector3(0.0, 0.84, 0.0), out * 0.9 + side * 0.09 + Vector3(0.0, 0.1, 0.0), out * 0.9 - side * 0.09 + Vector3(0.0, 0.1, 0.0), stripe, out + Vector3.UP)
		# a tentacle, hanging in a slight curve
		var top := out * 0.78 + Vector3(0.0, 0.05, 0.0)
		var mid := out * 0.95 + Vector3(rng.randf_range(-0.2, 0.2), -1.4, rng.randf_range(-0.2, 0.2))
		var tip := out * 0.7 + Vector3(rng.randf_range(-0.3, 0.3), -rng.randf_range(2.6, 3.6), rng.randf_range(-0.3, 0.3))
		frustum(mb, top, mid, 0.05, 0.035, 3, stripe, false)
		frustum(mb, mid, tip, 0.035, 0.01, 3, stripe, false)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var o := Vector3(cos(a), 0.0, sin(a)) * 0.22
		var end := o * 1.6 + Vector3(0.0, -rng.randf_range(1.5, 2.1), 0.0)
		frustum(mb, o, o.lerp(end, 0.5) + Vector3(0.12, 0.0, -0.1), 0.2, 0.15, 4, pale, false, rng)
		frustum(mb, o.lerp(end, 0.5) + Vector3(0.12, 0.0, -0.1), end, 0.15, 0.03, 4, pale, false, rng)
	return mb.build()


## A small fishing boat: a painted hull, a white wheelhouse forward, a mast and boom, and a
## pile of crab pots on the deck aft.
static func boat(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	var hull: Color = [Color(0.16, 0.3, 0.5), Color(0.6, 0.14, 0.12), Color(0.12, 0.4, 0.34), Color(0.85, 0.85, 0.8), Color(0.2, 0.2, 0.24)][rng.randi() % 5]
	var white := Color(0.93, 0.93, 0.88)
	box(mb, b * Vector3(0.0, 0.6, 0.0), Vector3(3.6, 2.2, 11.0), hull, rng, 0.08, b)
	# the bow: narrower, and a little higher
	box(mb, b * Vector3(0.0, 0.9, 6.3), Vector3(2.4, 2.4, 2.2), hull, rng, 0.08, b)
	box(mb, b * Vector3(0.0, 1.78, 0.0), Vector3(3.8, 0.22, 11.2), white, null, 0.0, b)
	box(mb, b * Vector3(0.0, 3.0, 2.6), Vector3(2.6, 2.3, 3.0), white, rng, 0.05, b)
	box(mb, b * Vector3(0.0, 3.3, 4.12), Vector3(2.2, 0.8, 0.1), Color(0.1, 0.16, 0.24), null, 0.0, b)
	box(mb, b * Vector3(0.0, 4.3, 2.6), Vector3(2.9, 0.2, 3.4), hull, null, 0.0, b)
	frustum(mb, b * Vector3(0.0, 4.3, 1.6), b * Vector3(0.0, 8.2, 1.6), 0.1, 0.06, 4, Color(0.3, 0.3, 0.32), false)
	frustum(mb, b * Vector3(0.0, 6.6, 1.6), b * Vector3(0.0, 4.6, -3.6), 0.07, 0.05, 4, Color(0.3, 0.3, 0.32), false)
	blob(mb, b * Vector3(0.0, 8.4, 1.6), Vector3(0.16, 0.16, 0.16), rng, glow(Color(1.0, 0.9, 0.5), 0.8), 4, 2, 0.0)
	for k in rng.randi_range(2, 5):
		box(mb, b * Vector3(rng.randf_range(-0.9, 0.9), 2.3 + 0.75 * (k / 2), -2.2 - 1.3 * (k % 2)), Vector3(1.4, 0.7, 1.2), Color(0.85, 0.62, 0.2), rng, 0.06, b)
	return mb.build()


## One tube of a landing splash: an open wall of radius 1 and height 1, flaring out a little
## towards the top (the node is scaled to size, and shaders/splash.gdshader cuts its crest).
static func splash_tube() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 28
	var rows := 4
	for j in rows + 1:
		var v := float(j) / rows
		var radius := 1.0 + 0.16 * v * v
		for i in seg + 1:
			var a := TAU * i / seg
			st.set_uv(Vector2(float(i) / seg, v))
			st.add_vertex(Vector3(cos(a) * radius, v, sin(a) * radius))
	for j in rows:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			for k: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(k)
	return st.commit()


## A whole salmon shark, for the field guide (in the sea only its head and fin are ever seen):
## a stout grey body, white underneath, with a tall dorsal fin, long pectorals and a crescent
## tail. Nose at -Z, about four long.
static func shark_whole() -> ArrayMesh:
	var mb := MB.new()
	var grey := Color(0.3, 0.38, 0.5)
	var dark := Color(0.2, 0.26, 0.38)
	var white := Color(0.93, 0.95, 0.97)
	# z, half-width, half-height, y-centre
	var rings := [
		[-2.0, 0.04, 0.04, -0.05],
		[-1.6, 0.26, 0.24, -0.02],
		[-1.0, 0.42, 0.44, 0.02],
		[-0.3, 0.46, 0.52, 0.04],
		[0.5, 0.36, 0.4, 0.03],
		[1.2, 0.18, 0.2, 0.02],
		[1.65, 0.08, 0.09, 0.02],
	]
	var sides := 8
	for k in rings.size() - 1:
		var ra: Array = rings[k]
		var rb: Array = rings[k + 1]
		var axis := Vector3(0.0, (ra[3] + rb[3]) * 0.5, (ra[0] + rb[0]) * 0.5)
		for i in sides:
			var a0 := TAU * i / sides + PI / sides
			var a1 := TAU * (i + 1) / sides + PI / sides
			var pa0 := Vector3(cos(a0) * ra[1], ra[3] + sin(a0) * ra[2], ra[0])
			var pa1 := Vector3(cos(a1) * ra[1], ra[3] + sin(a1) * ra[2], ra[0])
			var pb0 := Vector3(cos(a0) * rb[1], rb[3] + sin(a0) * rb[2], rb[0])
			var pb1 := Vector3(cos(a1) * rb[1], rb[3] + sin(a1) * rb[2], rb[0])
			var sn := sin((a0 + a1) * 0.5)
			var col := white if sn < -0.3 else (dark if sn > 0.6 else grey)
			mb.tri_out(pa0, pa1, pb1, col, axis)
			mb.tri_out(pa0, pb1, pb0, col, axis)
	var nose := Vector3(0.0, -0.05, -2.08)
	for i in sides:
		var a0 := TAU * i / sides + PI / sides
		var a1 := TAU * (i + 1) / sides + PI / sides
		mb.tri(nose, Vector3(cos(a0) * 0.04, -0.05 + sin(a0) * 0.04, -2.0), Vector3(cos(a1) * 0.04, -0.05 + sin(a1) * 0.04, -2.0), grey, Vector3.FORWARD)
	# the crescent tail, the upper lobe the longer
	var root_up := Vector3(0.0, 0.1, 1.6)
	var root_down := Vector3(0.0, -0.06, 1.6)
	var notch := Vector3(0.0, 0.02, 1.86)
	mb.tri(root_up, Vector3(0.0, 0.95, 2.2), notch, dark, Vector3.RIGHT)
	mb.tri(root_down, notch, Vector3(0.0, -0.7, 2.1), dark, Vector3.RIGHT)
	mb.tri(root_up, notch, root_down, dark, Vector3.RIGHT)
	# the dorsal fin, a small second one, and one underneath
	mb.tri(Vector3(0.0, 0.5, -0.7), Vector3(0.0, 1.25, -0.05), Vector3(0.0, 0.48, 0.2), dark, Vector3.RIGHT)
	mb.tri(Vector3(0.0, 0.2, 1.05), Vector3(0.0, 0.42, 1.3), Vector3(0.0, 0.16, 1.32), dark, Vector3.RIGHT)
	mb.tri(Vector3(0.0, -0.2, 0.95), Vector3(0.0, -0.44, 1.22), Vector3(0.0, -0.14, 1.26), grey, Vector3.RIGHT)
	for sx: float in [-1.0, 1.0]:
		# long pectoral fins
		mb.tri(Vector3(sx * 0.34, -0.2, -1.0), Vector3(sx * 1.25, -0.62, -0.25), Vector3(sx * 0.36, -0.26, -0.45), grey, Vector3.UP)
		# the eye, the gill slits and the line of the mouth
		var e := Vector3(sx * 0.262, 0.06, -1.58)
		mb.quad(e + Vector3(0, 0.05, -0.05), e + Vector3(0, 0.05, 0.05), e + Vector3(0, -0.05, 0.05), e + Vector3(0, -0.05, -0.05), Color(0.02, 0.02, 0.03), Vector3(sx, 0, 0))
		for g in 3:
			var c := Vector3(sx * (0.4 + 0.012 * g), 0.0, -1.12 + 0.11 * g)
			mb.quad(c + Vector3(0, 0.17, -0.015), c + Vector3(0, 0.17, 0.015), c + Vector3(0, -0.17, 0.015), c + Vector3(0, -0.17, -0.015), dark, Vector3(sx, 0, 0))
	return mb.build()


## A small fish of the kind that goes about in shoals (a herring, say): a few flat faces, as
## there are a great many of them. Its nose is at -z.
static func small_fish(back: Color, flank: Color) -> ArrayMesh:
	var mb := MB.new()
	var nose := Vector3(0.0, 0.0, -0.5)
	var tail := Vector3(0.0, 0.0, 0.32)
	var top := Vector3(0.0, 0.16, -0.08)
	var bottom := Vector3(0.0, -0.14, -0.08)
	for side: float in [-1.0, 1.0]:
		var mid := Vector3(side * 0.07, 0.0, -0.1)
		var out := Vector3(side, 0.0, 0.0)
		mb.tri(nose, top, mid, back, out + Vector3.UP)
		mb.tri(top, tail, mid, back, out + Vector3.UP)
		mb.tri(nose, mid, bottom, flank, out + Vector3.DOWN)
		mb.tri(mid, tail, bottom, flank, out + Vector3.DOWN)
		# the tail fin, seen from both sides
		mb.tri(tail, Vector3(0.0, 0.17, 0.56), Vector3(0.0, -0.17, 0.56), back, out)
	return mb.build()
