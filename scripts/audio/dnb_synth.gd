extends RefCounted
## Procedural jungle / drum & bass synthesizer: breaks, reese bass, pads, stabs, birds.
## Used offline by tools/bake_audio.gd to render the soundtrack into WAV files, because
## per-sample GDScript is far too slow to run live in a web build.

const BPM := 174.0
const MIX_RATE := 22050.0
const STEPS := 16
const BARS := 4
const SEC_PER_BEAT := 60.0 / BPM

const ENERGY := {"intro": 0.35, "build": 0.6, "drop": 1.0, "drop2": 1.0, "breakdown": 0.45}

# 16-step drum lanes: k = kick, s = snare, g = ghost snare, h = closed hat, o = open hat
const PATTERNS := {
	"A": {"k": "x.x.......xx....", "s": "....x.......x...", "g": ".......x.x....x.", "h": "x.x.x.x.x.x.x.x.", "o": "..............x."},
	"A2": {"k": "x.x...x..x......", "s": "....x.......x.x.", "g": ".x.....x.x.x....", "h": "xxx.xxx.xxx.xxx.", "o": ""},
	"B": {"k": "x.........x.....", "s": "....x.......x...", "g": "..x....x.x....x.", "h": "x.x.x.x.x.x.x.x.", "o": "......x........."},
	"FILL": {"k": "x.x.......x.....", "s": "....x..x.xx.xxxx", "g": "", "h": "x.x.x.x.x.x.....", "o": ""},
	"ROLL": {"k": "x.......x.......", "s": "x.x.x.x.xxxxxxxx", "g": "", "h": "x.x.x.x.........", "o": ""},
	"INTRO": {"k": "x...............", "s": "", "g": "....x.......x...", "h": "..x...x...x...x.", "o": ""},
	"RIDE": {"k": "", "s": "", "g": "", "h": "", "o": "..x...x...x...x."},
}

const E_MIN9 := [164.81, 196.00, 246.94, 293.66, 369.99]
const C_MAJ7 := [130.81, 164.81, 196.00, 246.94]
const D_SIX := [146.83, 185.00, 220.00, 329.63]
const B_MIN7 := [123.47, 146.83, 185.00, 220.00]
const G_MAJ := [196.00, 246.94, 293.66, 392.00]
# "liquid" style (A minor)
const A_MIN9 := [220.00, 246.94, 261.63, 329.63, 392.00]
const F_MAJ7 := [174.61, 220.00, 261.63, 329.63]
const G_SIX := [196.00, 246.94, 293.66, 329.63]
# "dark" style (D minor)
const D_MIN9 := [146.83, 174.61, 220.00, 261.63, 329.63]
const BB_MAJ7 := [116.54, 146.83, 174.61, 220.00]
const G_MIN7 := [196.00, 233.08, 293.66, 349.23]
const A_SEVEN := [220.00, 277.18, 329.63, 392.00]

## Each style renders the same five sections in its own key and mood.
const STYLES: Array[String] = ["jungle", "liquid", "dark"]

const RENDER_ORDER: Array[String] = ["intro", "build", "drop", "breakdown", "drop2"]

class Job:
	var name := ""
	var bars: Array = []
	var chords: Array = []
	var roots: Array = []
	var reese := false
	var sub := true
	var pad_amp := 0.05
	var stabs := false
	var birds := false
	## How fast the reese bass filter sweeps (cycles per beat).
	var wobble := 0.5
	var rng := RandomNumberGenerator.new()
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	var out := PackedVector2Array()
	var total := 0
	var bar := -1
	var i := 0
	var bar_start := 0
	var bar_end := 0
	var finalizing := false
	var lp := 0.0
	var ph1 := 0.0
	var ph2 := 0.0
	var ph_sub := 0.0
	var phases_l: Array[float] = []
	var phases_r: Array[float] = []

var _kick := PackedFloat32Array()
var _snare := PackedFloat32Array()
var _hat := PackedFloat32Array()
var _ohat := PackedFloat32Array()


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 174
	_kick = _make_kick()
	_snare = _make_snare(rng)
	_hat = _make_hat(rng, 0.045, 75.0)
	_ohat = _make_hat(rng, 0.22, 13.0)


## Renders one 4-bar section as stereo frames.
func render_section(section_name: String, style := "jungle") -> PackedVector2Array:
	var job := _new_job(section_name)
	_apply_style(job, style)
	while not _step(job, 1 << 30):
		pass
	return job.out


func _new_job(section_name: String) -> Job:
	var job := Job.new()
	job.name = section_name
	job.rng.seed = hash(section_name)
	job.chords = [E_MIN9, E_MIN9, C_MAJ7, D_SIX]
	job.roots = [82.41, 82.41, 65.41, 73.42]
	match section_name:
		"intro":
			job.bars = ["INTRO", "INTRO", "INTRO", "INTRO"]
			job.pad_amp = 0.07
			job.birds = true
		"build":
			job.bars = ["B", "B", "B", "ROLL"]
			job.pad_amp = 0.06
		"drop":
			job.bars = ["A", "B", "A", "FILL"]
			job.reese = true
			job.sub = false
			job.pad_amp = 0.025
		"drop2":
			job.bars = ["A2", "A", "A2", "FILL"]
			job.chords = [E_MIN9, G_MAJ, C_MAJ7, B_MIN7]
			job.roots = [82.41, 98.0, 65.41, 61.74]
			job.reese = true
			job.sub = false
			job.pad_amp = 0.025
			job.stabs = true
		"breakdown":
			job.bars = ["RIDE", "RIDE", "RIDE", "RIDE"]
			job.chords = [E_MIN9, G_MAJ, C_MAJ7, B_MIN7]
			job.roots = [82.41, 98.0, 65.41, 61.74]
			job.pad_amp = 0.08
			job.birds = true
	job.total = int(roundf(MIX_RATE * SEC_PER_BEAT / 4.0 * STEPS * BARS))
	job.left.resize(job.total)
	job.right.resize(job.total)
	return job


## Re-voices a section for one of the other STYLES ("jungle" is the section as written).
func _apply_style(job: Job, style: String) -> void:
	var busy: bool = job.chords[1] == G_MAJ
	match style:
		"liquid":
			# rolling and mellow: lush pads, a slow filter sweep, birds everywhere, no stabs
			job.rng.seed = hash("liquid" + job.name)
			job.chords = [A_MIN9, C_MAJ7, F_MAJ7, G_SIX] if busy else [A_MIN9, A_MIN9, F_MAJ7, G_SIX]
			job.roots = [110.0, 65.41, 87.31, 98.0] if busy else [110.0, 110.0, 87.31, 98.0]
			job.pad_amp *= 1.5
			job.wobble = 0.25
			job.stabs = false
			job.birds = true
			if job.name == "drop":
				job.bars = ["B", "A", "B", "FILL"]
			elif job.name == "drop2":
				job.bars = ["A", "B", "A", "FILL"]
		"dark":
			# heavier: busy breaks, a fast wobble, stabs on every drop, no birds
			job.rng.seed = hash("dark" + job.name)
			job.chords = [D_MIN9, G_MIN7, BB_MAJ7, A_SEVEN] if busy else [D_MIN9, D_MIN9, BB_MAJ7, A_SEVEN]
			job.roots = [73.42, 98.0, 58.27, 110.0] if busy else [73.42, 73.42, 58.27, 110.0]
			job.pad_amp *= 0.7
			job.wobble = 1.0
			job.birds = false
			job.stabs = job.reese
			if job.name == "drop":
				job.bars = ["A2", "A2", "A", "ROLL"]
			elif job.name == "drop2":
				job.bars = ["A2", "A", "A2", "ROLL"]


## Renders up to `budget` samples of a section; returns true once it's finished.
func _step(job: Job, budget: int) -> bool:
	var step_frames := MIX_RATE * SEC_PER_BEAT / 4.0
	while budget > 0:
		if job.finalizing:
			var stop := mini(job.i + budget * 4, job.total)
			for k in range(job.i, stop):
				job.out[k] = Vector2(tanh(job.left[k] * 1.1) * 0.85, tanh(job.right[k] * 1.1) * 0.85)
			budget -= (stop - job.i) / 4 + 1
			job.i = stop
			if job.i >= job.total:
				return true
			continue
		if job.i >= job.bar_end:
			job.bar += 1
			if job.bar >= BARS:
				if job.birds:
					for k in 3:
						_bird(job.left, job.right, job.rng.randi_range(0, job.total - int(MIX_RATE * 0.4)), job.rng)
				job.finalizing = true
				job.i = 0
				job.out.resize(job.total)
				continue
			_start_bar(job, step_frames)
		var stop := mini(job.i + budget, job.bar_end)
		_synth(job, job.i, stop, step_frames)
		budget -= stop - job.i
		job.i = stop
	return false


func _start_bar(job: Job, step_frames: float) -> void:
	var bar := job.bar
	var bar_frames := step_frames * STEPS
	var pat: Dictionary = PATTERNS[job.bars[bar]]
	var fill: bool = job.bars[bar] in ["ROLL", "FILL"]
	for step in STEPS:
		var swing := step_frames * 0.06 if step % 2 == 1 else 0.0
		var f0 := int(bar * bar_frames + step * step_frames + swing)
		var roll_gain := 0.4 + 0.6 * float(step) / STEPS if fill else 1.0
		if _hit(pat, "k", step):
			_mix(job.left, job.right, _kick, f0, 0.9, 0.0)
		if _hit(pat, "s", step):
			_mix(job.left, job.right, _snare, f0, 0.75 * roll_gain, 0.05)
		if _hit(pat, "g", step):
			_mix(job.left, job.right, _snare, f0, 0.22 + job.rng.randf() * 0.08, -0.1)
		if _hit(pat, "h", step):
			_mix(job.left, job.right, _hat, f0, 0.35 + job.rng.randf() * 0.15, 0.35)
		if _hit(pat, "o", step):
			_mix(job.left, job.right, _ohat, f0, 0.4, 0.3)
	job.bar_start = int(bar * bar_frames)
	job.bar_end = mini(int((bar + 1) * bar_frames), job.total)
	job.i = job.bar_start
	job.phases_l.clear()
	job.phases_r.clear()
	for c in (job.chords[bar] as Array).size():
		job.phases_l.append(job.rng.randf() * TAU)
		job.phases_r.append(job.rng.randf() * TAU)
	if job.stabs and (bar == 1 or bar == 3):
		for st: int in [0, 3, 6]:
			_stab(job.left, job.right, job.chords[bar], int(job.bar_start + st * step_frames))


## Pads + bass for samples [from, to) of the current bar.
func _synth(job: Job, from: int, to: int, step_frames: float) -> void:
	var chord: Array = job.chords[job.bar]
	var root: float = job.roots[job.bar]
	var bar := job.bar
	var b0 := job.bar_start
	var bar_len := float(job.bar_end - b0)
	var left := job.left
	var right := job.right
	var phases_l := job.phases_l
	var phases_r := job.phases_r
	var pad_amp := job.pad_amp
	var lp := job.lp
	var ph1 := job.ph1
	var ph2 := job.ph2
	var ph_sub := job.ph_sub
	for i in range(from, to):
		var t := float(i - b0) / MIX_RATE
		var local := float(i - b0)
		var env := minf(1.0, t / 0.3) * minf(1.0, (bar_len - local) / (0.08 * MIX_RATE))
		var trem := 0.85 + 0.15 * sin(TAU * t * 0.7 + bar)
		var pl := 0.0
		var pr := 0.0
		for c in chord.size():
			var f: float = chord[c]
			phases_l[c] += TAU * f * 0.998 / MIX_RATE
			phases_r[c] += TAU * f * 1.002 / MIX_RATE
			pl += sin(phases_l[c]) + 0.2 * sin(phases_l[c] * 3.0)
			pr += sin(phases_r[c]) + 0.2 * sin(phases_r[c] * 3.0)
		left[i] += pl * pad_amp * env * trem
		right[i] += pr * pad_amp * env * trem

		var step_in_bar := local / step_frames
		if job.reese:
			# two detuned saws through a wobbling one-pole low-pass, gated in a 10+6 rhythm
			var gate_pos := step_in_bar if step_in_bar < 10.0 else step_in_bar - 10.0
			var gate_len := 10.0 if step_in_bar < 10.0 else 6.0
			var gate := minf(1.0, gate_pos * 8.0) * minf(1.0, (gate_len - gate_pos) * 4.0)
			ph1 += root * 1.004 / MIX_RATE
			ph2 += root * 0.996 / MIX_RATE
			ph1 -= floorf(ph1)
			ph2 -= floorf(ph2)
			var saw := (ph1 * 2.0 - 1.0) + (ph2 * 2.0 - 1.0)
			var song_beat := (bar * STEPS + step_in_bar) / 4.0
			var cutoff := 160.0 + 900.0 * (0.5 + 0.5 * sin(TAU * song_beat * job.wobble))
			lp += (1.0 - exp(-TAU * cutoff / MIX_RATE)) * (saw - lp)
			ph_sub += TAU * root * 0.5 / MIX_RATE
			var bass := (lp * 0.28 + sin(ph_sub) * 0.42) * gate
			left[i] += bass
			right[i] += bass
		elif job.sub:
			ph_sub += TAU * root * 0.5 / MIX_RATE
			var sub_env := minf(1.0, t / 0.05) * minf(1.0, (bar_len - local) / (0.05 * MIX_RATE))
			var s := sin(ph_sub) * 0.32 * sub_env
			left[i] += s
			right[i] += s
	job.lp = lp
	job.ph1 = ph1
	job.ph2 = ph2
	job.ph_sub = ph_sub


func _make_kick() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := i / MIX_RATE
		ph += TAU * (46.0 + 140.0 * exp(-t * 32.0)) / MIX_RATE
		out[i] = sin(ph) * exp(-t * 8.0) * 0.95
	return out


func _make_snare(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var t := i / MIX_RATE
		var nz := rng.randf_range(-1.0, 1.0)
		hp = 0.65 * (hp + nz - prev)
		prev = nz
		out[i] = sin(TAU * 188.0 * t) * exp(-t * 32.0) * 0.45 + hp * exp(-t * 15.0) * 0.6
	return out


func _make_hat(rng: RandomNumberGenerator, length: float, decay: float) -> PackedFloat32Array:
	var n := int(MIX_RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var t := i / MIX_RATE
		var nz := rng.randf_range(-1.0, 1.0)
		hp = 0.35 * (hp + nz - prev)
		prev = nz
		out[i] = hp * exp(-t * decay) * 0.5
	return out


func _hit(pat: Dictionary, lane: String, step: int) -> bool:
	var s: String = pat.get(lane, "")
	return step < s.length() and s[step] == "x"


func _mix(left: PackedFloat32Array, right: PackedFloat32Array, shot: PackedFloat32Array, at: int, vol: float, pan: float) -> void:
	var gl := vol * (1.0 - maxf(pan, 0.0))
	var gr := vol * (1.0 + minf(pan, 0.0))
	var n := mini(shot.size(), left.size() - at)
	for j in n:
		left[at + j] += shot[j] * gl
		right[at + j] += shot[j] * gr


func _stab(left: PackedFloat32Array, right: PackedFloat32Array, chord: Array, at: int) -> void:
	var n := mini(int(MIX_RATE * 0.2), left.size() - at)
	for j in n:
		var t := j / MIX_RATE
		var v := 0.0
		for f: float in chord:
			var p := fmod(t * f * 2.0, 1.0)
			v += 1.0 if p < 0.5 else -1.0
		v *= exp(-t * 16.0) * 0.035
		left[at + j] += v
		right[at + j] += v


func _bird(left: PackedFloat32Array, right: PackedFloat32Array, at: int, rng: RandomNumberGenerator) -> void:
	var base := rng.randf_range(2000.0, 3200.0)
	var pan := rng.randf_range(-0.8, 0.8)
	for chirp in 3:
		var c0 := at + int(chirp * MIX_RATE * 0.11)
		var n := mini(int(MIX_RATE * 0.07), left.size() - c0)
		var ph := 0.0
		for j in n:
			var t := j / MIX_RATE
			ph += TAU * (base + 1400.0 * t / 0.07) / MIX_RATE
			var v := sin(ph) * sin(PI * t / 0.07) * 0.05
			left[c0 + j] += v * (1.0 - maxf(pan, 0.0))
			right[c0 + j] += v * (1.0 + minf(pan, 0.0))
