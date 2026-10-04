extends RefCounted
## Song arrangements: 4-bar sections played back to back. Shared by the baker (which renders
## them into one WAV per song) and the Music autoload (which knows where the sections fall).

const TITLE_SONG: Array[String] = ["intro", "intro", "breakdown", "intro"]
const RACE_SONG: Array[String] = ["build", "drop", "drop", "drop2", "drop2", "breakdown",
		"build", "drop2", "drop", "drop2", "drop"]
## The race song loops back to its first drop.
const RACE_LOOP_SECTION := 1
const ENERGY := {"intro": 0.35, "build": 0.6, "drop": 1.0, "drop2": 1.0, "breakdown": 0.45}

## One race tune per level, in level order: the same arrangement in six synth styles, each at
## its own tempo.
const TRACKS := [
	{"name": "ABYSSAL", "style": "deep", "bpm": 150.0, "file": "res://audio/race_deep.wav"},
	{"name": "REEF BREAK", "style": "liquid", "bpm": 160.0, "file": "res://audio/race_liquid.wav"},
	{"name": "RIVER MOUTH", "style": "coast", "bpm": 166.0, "file": "res://audio/race_coast.wav"},
	{"name": "JUNGLE FALLS", "style": "jungle", "bpm": 174.0, "file": "res://audio/race.wav"},
	{"name": "WHITE WATER", "style": "dark", "bpm": 186.0, "file": "res://audio/race_dark.wav"},
	{"name": "HOMECOMING", "style": "home", "bpm": 178.0, "file": "res://audio/race_home.wav"},
]
