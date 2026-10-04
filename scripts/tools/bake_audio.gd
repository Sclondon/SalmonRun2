extends SceneTree
## Renders the procedural soundtrack and sound effects into res://audio/*.wav.
## Run after changing audio/dnb_synth.gd or audio/sfx_synth.gd:
##   godot --headless --path . -s scripts/tools/bake_audio.gd
## then `godot --headless --path . --import` to import the new files.

const DnbSynth := preload("res://scripts/audio/dnb_synth.gd")
const SfxSynth := preload("res://scripts/audio/sfx_synth.gd")
const Songs := preload("res://scripts/audio/songs.gd")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio/sfx"))
	var synth := DnbSynth.new()
	for track: Dictionary in Songs.TRACKS:
		var sections := {}
		for section_name in DnbSynth.RENDER_ORDER:
			sections[section_name] = synth.render_section(section_name, track.style, track.bpm)
			print("rendered ", track.style, " ", section_name)
		_save_song(track.file, Songs.RACE_SONG, sections)
		if track.style == "jungle":
			_save_song("res://audio/title.wav", Songs.TITLE_SONG, sections)
	var sfx := SfxSynth.new().build_all()
	for sound: String in sfx:
		_save_mono("res://audio/sfx/%s.wav" % sound, sfx[sound])
	print("baked ", sfx.size(), " sound effects")
	quit()


func _save_song(path: String, song: Array[String], sections: Dictionary) -> void:
	var frames := 0
	for s in song:
		frames += (sections[s] as PackedVector2Array).size()
	var data := PackedByteArray()
	data.resize(frames * 4)
	var at := 0
	for s in song:
		var buf: PackedVector2Array = sections[s]
		for v in buf:
			data.encode_s16(at, int(clampf(v.x, -1.0, 1.0) * 32767.0))
			data.encode_s16(at + 2, int(clampf(v.y, -1.0, 1.0) * 32767.0))
			at += 4
	_write(path, data, true)
	print("saved ", path, " (", frames, " frames)")


func _save_mono(path: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	_write(path, data, false)


func _write(path: String, data: PackedByteArray, stereo: bool) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(DnbSynth.MIX_RATE)
	w.stereo = stereo
	w.data = data
	w.save_to_wav(ProjectSettings.globalize_path(path))
