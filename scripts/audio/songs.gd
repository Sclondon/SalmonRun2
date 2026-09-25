extends RefCounted
## Song arrangements: 4-bar sections played back to back. Shared by the baker (which renders
## them into one WAV per song) and the Music autoload (which knows where the sections fall).

const TITLE_SONG: Array[String] = ["intro", "intro", "breakdown", "intro"]
const RACE_SONG: Array[String] = ["build", "drop", "drop", "drop2", "drop2", "breakdown",
		"build", "drop2", "drop", "drop2", "drop"]
## The race song loops back to its first drop.
const RACE_LOOP_SECTION := 1
const ENERGY := {"intro": 0.35, "build": 0.6, "drop": 1.0, "drop2": 1.0, "breakdown": 0.45}
