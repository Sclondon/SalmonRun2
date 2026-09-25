extends Node
## Sound-effect bank. The sounds are synthesized offline (audio/sfx_synth.gd) and baked into
## res://audio/sfx/*.wav by tools/bake_audio.gd, so the game has no third-party audio.

const SOUNDS := ["splash", "land", "jump", "trick", "ding", "ring", "combo", "wipeout", "bank",
		"boost", "count", "go", "bear", "ui", "grind"]
const LOOPING := ["grind"]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	for sound: String in SOUNDS:
		var w: AudioStreamWAV = load("res://audio/sfx/%s.wav" % sound)
		if sound in LOOPING:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(roundf(w.get_length() * w.mix_rate))
		_streams[sound] = w


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Starts/stops a looping sound (e.g. the grind).
func set_loop(sound: String, on: bool) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "Sfx"
		p.stream = _streams.get(sound)
		add_child(p)
		_loops[sound] = p
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()
