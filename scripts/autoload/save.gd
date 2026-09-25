extends Node
## Persistent settings + high score (user://salmonrun2.cfg).

const PATH := "user://salmonrun2.cfg"

var best_score := 0
var best_rank := "-"
var music_volume := 0.8
var sfx_volume := 0.9
## Phones render at a lower resolution by default (bigger pixels, much cheaper)
var pixel_scale := 4 if is_mobile() else 3


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	best_score = cfg.get_value("score", "best", 0)
	best_rank = cfg.get_value("score", "rank", "-")
	music_volume = cfg.get_value("settings", "music", 0.8)
	sfx_volume = cfg.get_value("settings", "sfx", 0.9)
	pixel_scale = cfg.get_value("settings", "pixel_scale", pixel_scale)


func store() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.set_value("score", "rank", best_rank)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "sfx", sfx_volume)
	cfg.set_value("settings", "pixel_scale", pixel_scale)
	cfg.save(PATH)


## Returns true when this is a new best.
func submit_score(score: int, rank: String) -> bool:
	if score <= best_score:
		return false
	best_score = score
	best_rank = rank
	store()
	return true


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
