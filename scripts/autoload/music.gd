extends Node
## Plays the jungle / drum & bass soundtrack and runs the beat clock used by gameplay (on-beat
## landings) and visuals (the `beat_pulse` shader global).
##
## The songs are rendered offline from audio/dnb_synth.gd into res://audio/*.wav by
## tools/bake_audio.gd — synthesizing live is far too slow for the web build.

signal beat(index: int)

const Songs := preload("res://scripts/audio/songs.gd")

const TITLE_BPM := 174.0
## Tempo of the song that is playing; every track has its own.
var bpm := TITLE_BPM
var sec_per_beat := 60.0 / TITLE_BPM
const SECTION_BEATS := 16.0

var is_ready := true
var energy := 0.0
var song_time := -1.0

var _player: AudioStreamPlayer
var _title: AudioStreamWAV
var _races := {}  # track index -> AudioStreamWAV
var _song: Array[String] = []
var _loop_section := 0
var _loop_seconds := 0.0
var _last_raw := 0.0
var _stuck := 0.0
var _wrap := 0.0
var _clock_started := false
var _last_beat := -1
var _lowpass: AudioEffectLowPassFilter
var _cutoff := 20000.0
var _cutoff_target := 20000.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	# Web builds default to "sample" playback, which ignores bus effects (our low-pass).
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_title = _load_song("res://audio/title.wav", Songs.TITLE_SONG, 0)
	play_title()


func _load_song(path: String, song: Array[String], loop_section: int) -> AudioStreamWAV:
	var w: AudioStreamWAV = load(path)
	var frames := int(roundf(w.get_length() * w.mix_rate))
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = frames / song.size() * loop_section
	w.loop_end = frames
	return w


func _setup_buses() -> void:
	for bus_name: String in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _lowpass)
	apply_volumes()


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(Save.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sfx"), linear_to_db(maxf(Save.sfx_volume, 0.0001)))


func play_title() -> void:
	_play(_title, Songs.TITLE_SONG, 0, TITLE_BPM)


## Starts a level's race tune from the top (the beat clock restarts at 0).
func play_race(level: int) -> void:
	var i := clampi(level, 0, Songs.TRACKS.size() - 1)
	if not _races.has(i):
		_races[i] = _load_song(Songs.TRACKS[i].file, Songs.RACE_SONG, Songs.RACE_LOOP_SECTION)
	_play(_races[i], Songs.RACE_SONG, Songs.RACE_LOOP_SECTION, Songs.TRACKS[i].bpm)


func _play(stream: AudioStreamWAV, song: Array[String], loop_section: int, tempo: float) -> void:
	bpm = tempo
	sec_per_beat = 60.0 / tempo
	_song = song
	_loop_section = loop_section
	_loop_seconds = SECTION_BEATS * sec_per_beat * (song.size() - loop_section)
	_last_raw = 0.0
	_wrap = 0.0
	_stuck = 0.0
	_clock_started = false
	_last_beat = -1
	song_time = -1.0
	_player.stream = stream
	_player.play()


## Muffles the music (e.g. wipeouts, big air). 20000 = fully open.
func set_filter(hz: float) -> void:
	_cutoff_target = clampf(hz, 200.0, 20000.0)


func beat_float() -> float:
	return song_time / sec_per_beat


## Signed seconds from the nearest beat (0 = exactly on the beat).
func beat_offset() -> float:
	var b := beat_float()
	return (b - roundf(b)) * sec_per_beat


## 1.0 right on the beat, decaying to 0 before the next one; scaled by section energy.
func beat_pulse() -> float:
	var f := beat_float()
	if f < 0.0:
		return 0.0
	var p := 1.0 - (f - floorf(f))
	return p * p * p * (0.35 + 0.65 * energy)


func _process(delta: float) -> void:
	_update_clock(delta)
	_cutoff = exp(lerpf(log(_cutoff), log(_cutoff_target), 1.0 - exp(-delta * 6.0)))
	_lowpass.cutoff_hz = _cutoff
	RenderingServer.global_shader_parameter_set("beat_pulse", beat_pulse())


func _update_clock(delta: float) -> void:
	var raw := _player.get_playback_position() if _player.playing else _last_raw
	if raw < _last_raw - 1.0:
		_wrap += _loop_seconds
	# Browsers keep audio suspended until the player interacts with the page; if the song isn't
	# advancing, free-run the clock on frame time so countdowns and bears still work.
	_stuck = _stuck + delta if is_equal_approx(raw, _last_raw) else 0.0
	_last_raw = raw
	if _stuck > 0.25:
		song_time = maxf(song_time, 0.0) + delta
		_clock_started = false
	else:
		_sync_clock(raw, delta)
	var section := int(floorf(maxf(song_time, 0.0) / (SECTION_BEATS * sec_per_beat)))
	if section >= _song.size():
		section = _loop_section + (section - _loop_section) % (_song.size() - _loop_section)
	energy = lerpf(energy, float(Songs.ENERGY.get(_song[section], 0.5)), 0.1)
	var b := int(floorf(beat_float()))
	if b != _last_beat and b >= 0:
		_last_beat = b
		beat.emit(b)


func _sync_clock(raw: float, delta: float) -> void:
	var measured := raw + _wrap + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	if not _clock_started:
		song_time = measured
		_clock_started = true
	else:
		# Advance smoothly with frame time, gently corrected towards the audio position.
		song_time += delta
		var err := measured - song_time
		if absf(err) > 0.12:
			song_time = measured
		else:
			song_time += err * 0.08
