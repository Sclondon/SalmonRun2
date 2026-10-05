extends Node
## Persistent settings + high scores (user://salmonrun2.cfg).

const PATH := "user://salmonrun2.cfg"
const LEVELS := 18

## Best run of each stage: stage index (+100 for the downstream leg) -> [score, rank]
var bests := {}
## The level played last (the title screen picks up from here)
var level := 0
## ...and whether that was on the way back downstream
var down := false
var music_volume := 0.8
var sfx_volume := 0.9
## The retro filter. Phones render at a lower resolution by default (bigger pixels, much
## cheaper); the rest are 0 to 1: colour banding and dither, PS1 vertex wobble, dark corners.
var pixel_scale := 3 if is_mobile() else 2
var dither := 0.5
var wobble := 0.5
var vignette := 0.4
## Shows the testing shortcuts: start a run on any stage, and skip to the end of one
var tester := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	bests = cfg.get_value("score", "bests", {})
	# saves from before there were levels only knew the jungle river
	var old: int = cfg.get_value("score", "best", 0)
	if old > 0 and not bests.has(3):
		bests[3] = [old, cfg.get_value("score", "rank", "-")]
	level = clampi(cfg.get_value("score", "level", 0), 0, LEVELS - 1)
	down = cfg.get_value("score", "down", false)
	music_volume = cfg.get_value("settings", "music", 0.8)
	sfx_volume = cfg.get_value("settings", "sfx", 0.9)
	# ("pixel_size", not the old "pixel_scale": the default got gentler, so old saves take it up)
	pixel_scale = cfg.get_value("settings", "pixel_size", pixel_scale)
	dither = cfg.get_value("settings", "dither", dither)
	wobble = cfg.get_value("settings", "wobble", wobble)
	vignette = cfg.get_value("settings", "vignette", vignette)
	tester = cfg.get_value("settings", "tester", false)


func store() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "bests", bests)
	cfg.set_value("score", "level", level)
	cfg.set_value("score", "down", down)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "sfx", sfx_volume)
	cfg.set_value("settings", "pixel_size", pixel_scale)
	cfg.set_value("settings", "dither", dither)
	cfg.set_value("settings", "wobble", wobble)
	cfg.set_value("settings", "vignette", vignette)
	cfg.set_value("settings", "tester", tester)
	cfg.save(PATH)


func best(of_level: int) -> int:
	return int(bests[of_level][0]) if bests.has(of_level) else 0


func rank(of_level: int) -> String:
	return str(bests[of_level][1]) if bests.has(of_level) else "-"


## Returns true when this is a new best for the level.
func submit_score(of_level: int, score: int, new_rank: String) -> bool:
	if score <= best(of_level):
		return false
	bests[of_level] = [score, new_rank]
	store()
	return true


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
