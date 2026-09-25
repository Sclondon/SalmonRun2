extends RefCounted
## Procedural sound-effect synthesizer, used offline by tools/bake_audio.gd.

const RATE := 22050
const LOOPING := ["grind"]

var _rng := RandomNumberGenerator.new()


## name -> mono samples
func build_all() -> Dictionary:
	_rng.seed = 7
	return {
		"splash": _noise_burst(0.45, 0.25, 7.0, 0.8),
		"land": _land(),
		"jump": _jump(),
		"trick": _tones([1318.5, 1975.5], 0.0, 0.4, 8.0, 0.25),
		"ding": _tones([2637.0, 3951.0], 0.0, 0.3, 14.0, 0.2),
		"ring": _tones([659.3, 830.6, 987.8, 1318.5], 0.05, 0.35, 10.0, 0.2),
		"combo": _tones([659.3, 987.8, 1318.5, 1661.2, 1975.5], 0.07, 0.6, 6.0, 0.18),
		"wipeout": _wipeout(),
		"bank": _thud(),
		"boost": _sweep(0.6),
		"count": _tones([880.0], 0.0, 0.15, 12.0, 0.3),
		"go": _tones([880.0, 1760.0], 0.0, 0.5, 5.0, 0.3),
		"bear": _growl(),
		"ui": _tones([1200.0], 0.0, 0.06, 40.0, 0.2),
		"grind": _grind(),
	}


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * seconds))
	return b


func _noise_burst(seconds: float, lp_amount: float, decay: float, vol: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += lp_amount * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * exp(-t * decay) * (1.0 - exp(-t * 200.0)) * vol * 2.0
	return b


func _land() -> PackedFloat32Array:
	var b := _noise_burst(0.35, 0.3, 9.0, 0.6)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (60.0 + 90.0 * exp(-t * 30.0)) / RATE
		b[i] += sin(ph) * exp(-t * 14.0) * 0.6
	return b


func _jump() -> PackedFloat32Array:
	var b := _buf(0.28)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 0.28
		lp += (0.05 + 0.5 * k) * (_rng.randf_range(-1.0, 1.0) - lp)
		ph += TAU * (300.0 + 700.0 * k) / RATE
		b[i] = (lp * 0.6 + sin(ph) * 0.15) * sin(PI * k)
	return b


func _tones(freqs: Array, spacing: float, seconds: float, decay: float, vol: float) -> PackedFloat32Array:
	var b := _buf(seconds + spacing * freqs.size())
	for n in freqs.size():
		var f: float = freqs[n]
		var start := int(n * spacing * RATE)
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			var v := sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)
			b[i] += v * exp(-t * decay) * vol * minf(1.0, t * 400.0)
	return b


func _wipeout() -> PackedFloat32Array:
	var b := _buf(0.8)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += (300.0 * exp(-t * 2.5) + 50.0) / RATE
		var sq := 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		b[i] = (sq * 0.18 + _rng.randf_range(-1.0, 1.0) * 0.25 * exp(-t * 5.0)) * exp(-t * 2.0)
	return b


func _thud() -> PackedFloat32Array:
	var b := _buf(0.2)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 80.0 * t) * exp(-t * 22.0) * 0.7 + _rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.3
	return b


func _sweep(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var lp := 0.0
	for i in b.size():
		var k := float(i) / b.size()
		lp += (0.02 + 0.4 * k) * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * sin(PI * k) * 1.2
	return b


func _growl() -> PackedFloat32Array:
	var b := _buf(0.7)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += (70.0 + 15.0 * sin(t * 30.0)) / RATE
		lp += 0.02 * (_rng.randf_range(-1.0, 1.0) - lp)
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		b[i] = saw * (0.5 + 4.0 * absf(lp)) * sin(PI * t / 0.7) * 0.35
	return b


func _grind() -> PackedFloat32Array:
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.3 * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * (0.6 + 0.4 * sin(TAU * 32.0 * t)) * 0.35
	return b
