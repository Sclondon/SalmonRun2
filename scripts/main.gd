extends Node
## Game flow: title -> countdown -> race -> results. Also owns the pixelated render target,
## the HUD and all menus.
##
## Run with `-- --autotest=<dir>` to play a race on autopilot, save screenshots to <dir>
## and print a summary (used for automated smoke tests). Add `--practice` to run the practice level.

const World := preload("res://scripts/world/world.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Score := preload("res://scripts/game/score.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const ChaseCam := preload("res://scripts/world/chase_camera.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const TitleLogo := preload("res://scripts/ui/title_logo.gd")
const Songs := preload("res://scripts/audio/songs.gd")
const Levels := preload("res://scripts/world/levels.gd")
const Globe := preload("res://scripts/ui/globe.gd")

const PRACTICE_HINT := "HOLD: SWIM TO YOUR FINGER      SWIPE UP: JUMP      LITTLE CIRCLES: BOOST\nIN THE AIR: SWIPE TO SPIN / FLIP THAT WAY      JUMP UP THE WATERFALL"

enum Phase { TITLE, COUNTDOWN, RACE, FINISHED }

var phase := Phase.TITLE
var world: World
var hud: Hud
var score := Score.new()
var race_time := 0.0

var _container: SubViewportContainer
var _menus: CanvasLayer
var _panels: Array[Control] = []
var _title: Control
var _title_sub: Label
var _howto: Control
var _options: Control
var _pause: Control
var _results: Control
var _loading: Label
var _title_best: Label
var _results_labels := {}
var _finish_timer := -1.0
var _filter_timer := 0.0
var _touch: TouchControls
var _use_touch := false
var _test_mode := false
## Which stage of the journey is being played (index into Levels.LIST)
var _level := 0
## On the way back down as the next generation (the seaward migration)
var _down := false
## The stages swum on the way up, in order, so the way down can retrace them
var _route: Array[int] = []
## Score banked over the run so far
var _journey := 0
var _next := -1
var _next_down := false
var _alt := -1
var _map_down := false
var _map_title: Label
var _map_start: Button
var _map_flip: Button
var _map_globe: Globe
var _travel_globe: Globe
## The stage the run has just come from (-1 at the start of one), for the line on the globe
var _from := -1
var _levels: Control
var _level_buttons: Array[Button] = []
var _travel: Control
var _travel_label: Label
var _travel_tag: Label
var _busy := false

var _autotest_dir := ""
var _autotest_t := 0.0
var _next_shot := 0.0
var _shots := 0
var _autotest_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_autotest_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--level="):
			Save.level = clampi(int(arg.get_slice("=", 1)) - 1, 0, Levels.LIST.size() - 1)
			Save.down = false
		elif arg == "--down":
			Save.down = true
		elif arg == "--practice":
			_test_mode = true
		elif arg == "--touch-ui":
			_use_touch = true
	_use_touch = _use_touch or DisplayServer.is_touchscreen_available()

	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.stretch_shrink = Save.pixel_scale
	var post := ShaderMaterial.new()
	post.shader = preload("res://shaders/post.gdshader")
	_container.material = post
	add_child(_container)
	var vp := SubViewport.new()
	_container.add_child(vp)
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	vp.add_child(world)

	hud = Hud.new()
	add_child(hud)
	hud.visible = false
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 3
	add_child(touch_layer)
	_touch = TouchControls.new()
	_touch.visible = false
	_touch.pause_pressed.connect(func() -> void:
		if phase == Phase.RACE and not get_tree().paused:
			_pause_game())
	touch_layer.add_child(_touch)
	_touch.player = world.player
	_touch.camera = world.camera
	_touch.view = _container
	_menus = CanvasLayer.new()
	_menus.layer = 5
	add_child(_menus)
	_build_menus()
	_build_levels()
	_level = Save.level
	_down = Save.down

	var p := world.player
	p.trick_landed.connect(_on_trick)
	p.wiped_out.connect(_on_wipe)
	p.bumped.connect(_on_bump)
	p.ring_collected.connect(_on_ring)
	p.jumped.connect(_on_jump)
	p.landed.connect(_on_land)
	Music.beat.connect(_on_beat)
	_enter_title()


# ================================================================== flow

func _enter_title() -> void:
	phase = Phase.TITLE
	get_tree().paused = false
	hud.visible = false
	_show(_title)
	Music.play_title()
	Music.set_filter(20000.0)
	world.track.reset_rings()
	var p := world.player
	p.reset(Track.START_S)
	p.autopilot = true
	p.control = false
	p.go()
	world.camera.mode = ChaseCam.Mode.CINEMA
	world.camera.snap()
	_title_sub.text = _track_text()
	var total := 0
	for key: int in Save.bests:
		total += Save.best(key)
	_title_best.text = "BEST OF EVERY STAGE  %s" % Hud.fmt(total) if total > 0 else ""


## The tune of the stage you're on (stages on the same tier of the map share one).
func _track_text() -> String:
	var t: Dictionary = Songs.TRACKS[Levels.LIST[_level].tier]
	return "%s   //   %d BPM" % [t.name, int(t.bpm)]


## Bests are kept per stage and per direction.
func _key() -> int:
	return _level + (100 if _down else 0)


func _leg_name(down: bool) -> String:
	return "SEAWARD MIGRATION" if down else "SPAWNING MIGRATION"


## `from` is the stage the run has just left (for the line across the globe), -1 for none.
func _start_level(index: int, down: bool, from := -99) -> void:
	_from = _level if from == -99 else from
	_level = index
	_down = down
	Save.level = index
	Save.down = down
	Save.store()
	_start_race()


## A fresh run from one stage of the map.
func _start_journey(index: int, down: bool) -> void:
	_route.clear()
	_journey = 0
	_start_level(index, down, -1)


func _objective_value() -> int:
	match Levels.LIST[_level].objective.type:
		"rings":
			return score.rings
		"on_beat":
			return score.on_beats
		"flow":
			return score.best_flow
		"score":
			return score.score
	return score.wipeouts


## Stages where the way on forks have a goal: meet it to stay on the wild route.
func _has_objective() -> bool:
	return not _test_mode and not _down and Levels.forks(_level) and Levels.LIST[_level].has("objective")


func _objective_met() -> bool:
	if not _has_objective():
		return false
	var o: Dictionary = Levels.LIST[_level].objective
	return _objective_value() <= int(o.n) if o.type == "clean" else _objective_value() >= int(o.n)


func _start_race(test := false) -> void:
	if _busy:
		return
	if not world.has_course(_level, test, _down):
		# building a level takes a moment: say where we're going, then let that frame draw first
		_busy = true
		_travel_label.text = "PRACTICE" if test else "%s\n%s" % [_leg_name(_down), Levels.LIST[_level].name]
		if test:
			_travel_tag.text = ""
		elif _down:
			_travel_tag.text = "SPRING. THE NEXT GENERATION HEADS FOR THE SEA"
		else:
			_travel_tag.text = str(Levels.LIST[_level].tagline)
		hud.visible = false
		_travel_globe.visible = not test
		if not test:
			var done: Array[int] = []
			if not _down:
				done = _route.duplicate()
			if _from == -1 or _from == _level:
				_travel_globe.look_at_stage(_level)
			_travel_globe.show_path(done, _from, _level, 1.3)
		_show(_travel)
		Music.set_filter(700.0)
		if not test and _from != -1 and _from != _level:
			# let the line reach the next stage before the screen freezes to build it
			await get_tree().create_timer(1.6).timeout
		await get_tree().process_frame
		await get_tree().process_frame
		_busy = false
	_test_mode = test
	world.set_course(_level, test, _down)
	_touch.hint = PRACTICE_HINT if test else ""
	GameInput.clear_touch()
	get_tree().paused = false
	_show(null)
	hud.visible = true
	hud.set_best(0 if test else Save.best(_key()))
	score.reset()
	race_time = 0.0
	_finish_timer = -1.0
	var p := world.player
	p.reset(Track.START_S)
	p.autopilot = _autotest_dir != ""
	p.control = false
	world.track.reset_rings()
	world.camera.mode = ChaseCam.Mode.FOLLOW
	world.camera.snap()
	Music.set_filter(20000.0)
	Music.play_race(Levels.LIST[Levels.JUNGLE if test else _level].tier)
	phase = Phase.COUNTDOWN
	if not test:
		hud.popup(Levels.LIST[_level].name, UI.CYAN, 2.6)
	if test:
		# no countdown, no finish line: just swim
		phase = Phase.RACE
		p.control = not p.autopilot
		p.go()


func _on_beat(b: int) -> void:
	if phase != Phase.COUNTDOWN:
		return
	match b:
		0, 2, 4:
			hud.countdown(str(3 - b / 2))
			Sfx.play("count")
		6:
			hud.countdown("GO!")
			Sfx.play("go")
			phase = Phase.RACE
			world.player.control = not world.player.autopilot
			world.player.go()


## Practice has no finish: swim through the arch and you're back at the start.
func _test_lap() -> void:
	var p := world.player
	p.reset(Track.START_S)
	p.go()
	world.track.reset_rings()
	world.camera.snap()
	hud.popup("ONE MORE LAP", UI.LIME, 1.0)


func _finish() -> void:
	phase = Phase.FINISHED
	hud.popup("FINISH!", UI.LIME, 2.5)
	Sfx.play("combo")
	world.player.control = false
	_finish_timer = 2.5


func _show_results() -> void:
	# shorter levels have less to score on, so rank against a full-length course
	var rank := Score.rank_for(int(score.score * 3400.0 / world.track.length))
	var new_best := _autotest_dir == "" and Save.submit_score(_key(), score.score, rank)
	# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score.score, true)
	_journey += score.score
	var l: Dictionary = _results_labels
	var stage: Dictionary = Levels.LIST[_level]
	var title := "%s CLEARED" % stage.name
	var route := ""
	_next = -1
	_alt = -1
	_next_down = _down
	var next_text := ""
	if _down:
		_next = Levels.prev_down(_level, _route)
		if _next == -1:
			title = "THE OPEN OCEAN. THE CYCLE BEGINS AGAIN"
			route = "TWO YEARS AT SEA, THEN THE LONG SWIM HOME"
	else:
		if _route.is_empty() or _route[-1] != _level:
			_route.append(_level)
		var met := _objective_met()
		var options := Levels.next_up(_level, met)
		if options.is_empty():
			# the end of the run up: spawn, and the young take it from here
			title = "HOME AT LAST. SPAWNED!" if int(stage.lane) == 0 else "SPAWNED... IN A FISH FARM"
			route = "THE ADULTS DIE HERE AND FEED THE RIVER. THEIR YOUNG HEAD FOR THE SEA"
			_next = _level
			_next_down = true
			next_text = "THE NEXT GENERATION"
		else:
			_next = options[0]
			if options.size() > 1:
				_alt = options[1]
			if _has_objective():
				route = "GOAL MET: THE WILD ROUTE IS OPEN" if met else "GOAL MISSED (%s): SWEPT OFF COURSE" % Levels.objective_text(_level)
	if next_text == "" and _next != -1:
		next_text = "NEXT: %s" % Levels.LIST[_next].name
	(l.title as Label).text = title
	(l.route as Label).text = route
	(l.route as Label).visible = route != ""
	(l.next as Button).visible = _next != -1
	(l.next as Button).text = next_text
	(l.alt as Button).visible = _alt != -1
	if _alt != -1:
		(l.alt as Button).text = "OR: %s" % Levels.LIST[_alt].name
	(l.rank as Label).text = rank
	(l.score as Label).text = Hud.fmt(score.score)
	(l.best as Label).text = "NEW BEST!" if new_best else "BEST  %s" % Hud.fmt(Save.best(_key()))
	(l.stats as Label).text = "\n".join([
		"JOURNEY SO FAR   %s" % Hud.fmt(_journey),
		"TIME   %s" % Hud.fmt_time(race_time),
		"TRICKS   %d      ON BEAT   %d" % [score.tricks, score.on_beats],
		"BEST TRICK   %s  (%s)" % [score.best_trick.to_upper() if score.best_trick != "" else "-", Hud.fmt(score.best_trick_pts)],
		"BEST FLOW   x%d" % score.best_flow,
		"RINGS   %d      WIPEOUTS   %d" % [score.rings, score.wipeouts],
	])
	_show(_results)
	if _autotest_dir != "":
		print("AUTOTEST RESULT score=%d rank=%s time=%.1f tricks=%d on_beat=%d rings=%d wipeouts=%d best='%s'" % [
			score.score, rank, race_time, score.tricks, score.on_beats, score.rings, score.wipeouts, score.best_trick])
		print("AUTOTEST ROUTE title='%s' next=%s alt=%s down=%s note='%s'" % [title, Levels.LIST[_next].name if _next != -1 else "-", Levels.LIST[_alt].name if _alt != -1 else "-", _next_down, route])


func _pause_game() -> void:
	get_tree().paused = true
	Music.set_filter(700.0)
	_show(_pause)


func _resume() -> void:
	get_tree().paused = false
	Music.set_filter(20000.0)
	_show(null)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if get_tree().paused:
		_resume()
	elif phase == Phase.RACE:
		_pause_game()
	elif _howto.visible or _options.visible or _levels.visible:
		_close_sub_panel()


func _input(event: InputEvent) -> void:
	# Show the on-screen controls for whichever the player is actually using
	if event is InputEventScreenTouch:
		_use_touch = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_use_touch = false


func _process(delta: float) -> void:
	var p := world.player
	_touch.visible = phase in [Phase.COUNTDOWN, Phase.RACE] and not get_tree().paused and not _travel.visible
	hud.set_touch_mode(_use_touch)
	_loading.visible = not Music.is_ready
	match phase:
		Phase.TITLE:
			if p.s > world.track.finish_s + 60.0:
				p.reset(Track.START_S)
				p.go()
				world.track.reset_rings()
		Phase.COUNTDOWN, Phase.RACE, Phase.FINISHED:
			if phase == Phase.RACE and not get_tree().paused:
				race_time += delta
			var had_flow := score.flow
			score.tick(delta, p.in_air())
			if had_flow > 1 and score.flow == 1 and phase == Phase.RACE:
				hud.popup("FLOW ENDED", UI.ORANGE, 0.8)
			var prog := clampf((p.s - Track.START_S) / (world.track.finish_s - Track.START_S), 0.0, 1.0)
			hud.set_stats(score.score, race_time, prog, p.boost, p.speed * 3.6)
			hud.set_flow(score.flow, score.timer / Score.FLOW_WINDOW)
			if _has_objective():
				hud.set_objective("%s   [%s]" % [Levels.objective_text(_level), Hud.fmt(_objective_value())], _objective_met())
			else:
				hud.set_objective("", false)
			if phase == Phase.RACE and p.s >= world.track.finish_s:
				if _test_mode:
					_test_lap()
				else:
					_finish()
			if not get_tree().paused:
				_filter_timer -= delta
				if p.state == Salmon.State.AIR and p.air_time > 0.9:
					Music.set_filter(1600.0)
				elif _filter_timer <= 0.0:
					Music.set_filter(20000.0)
			if _finish_timer > 0.0:
				_finish_timer -= delta
				if _finish_timer <= 0.0:
					_show_results()
	if _autotest_dir != "":
		_autotest(delta)


# ================================================================== events

func _sfx(sound: String, pitch := 1.0, db := 0.0) -> void:
	Sfx.play(sound, pitch, db - (14.0 if phase == Phase.TITLE else 0.0))


func _on_trick(trick: Dictionary) -> void:
	if _autotest_dir != "":
		print("  trick: %s  +%d  beat=%d  (s=%.0f)" % [trick.name, trick.points, trick.beat, world.player.s])
	if phase != Phase.RACE:
		return
	var flow := score.flow
	var gained := score.add_trick(trick)
	world.player.boost = minf(world.player.boost + float(trick.points) / 40.0, 100.0)
	hud.show_trick(trick.name, gained, flow, trick.beat)
	Sfx.play("trick", 1.0 + 0.06 * (flow - 1))
	if int(trick.beat) == 2:
		hud.popup("PERFECT BEAT!", UI.PINK, 0.9)
		Sfx.play("ding")
	elif int(trick.beat) == 1:
		hud.popup("ON BEAT!", UI.CYAN, 0.9)
		Sfx.play("ding", 0.8)


func _on_wipe(reason: String) -> void:
	if _autotest_dir != "":
		print("  WIPEOUT: %s (s=%.0f)" % [reason, world.player.s])
	world.camera.shake = 1.0
	_sfx("wipeout")
	_sfx("splash")
	if phase != Phase.RACE:
		return
	var lost_flow := score.drop()
	hud.popup(reason + ("\nFLOW LOST" if lost_flow > 1 else ""), UI.RED, 1.4)
	Music.set_filter(500.0)
	_filter_timer = 1.3


func _on_bump(reason: String) -> void:
	if _autotest_dir != "":
		print("  BUMP: %s (s=%.0f)" % [reason, world.player.s])
	world.camera.shake = maxf(world.camera.shake, 0.5)
	_sfx("bank")
	_sfx("splash", 1.2, -4.0)
	if phase != Phase.RACE:
		return
	var lost_flow := score.drop()
	hud.popup(reason + ("\nFLOW LOST" if lost_flow > 1 else ""), UI.RED, 1.0)
	Music.set_filter(900.0)
	_filter_timer = 0.4


func _on_ring(count: int) -> void:
	_sfx("ring", 1.0 + 0.05 * (score.rings % 8))
	if phase == Phase.RACE:
		score.add_rings(count)


func _on_jump() -> void:
	_sfx("jump", randf_range(0.9, 1.1), -3.0)


func _on_land(impact: float) -> void:
	_sfx("land", randf_range(0.9, 1.1), -2.0)
	world.camera.shake = maxf(world.camera.shake, clampf(impact / 30.0, 0.0, 0.7))


# ================================================================== menus

func _build_menus() -> void:
	# --- title
	_title = _panel_root()
	var col := VBoxContainer.new()
	col.position = Vector2(70, 40)
	col.add_theme_constant_override("separation", 14)
	_title.add_child(col)
	col.add_child(TitleLogo.new())
	_title_sub = UI.label("", 34, UI.CYAN, 10)
	col.add_child(_title_sub)
	col.add_child(UI.button("SWIM!", _open_levels))
	col.add_child(UI.button("PRACTICE", func() -> void: _start_race(true)))
	col.add_child(UI.button("OPTIONS", func() -> void: _open_sub_panel(_options)))
	if not OS.has_feature("web"):
		col.add_child(UI.button("QUIT", func() -> void: get_tree().quit()))
	_title_best = UI.label("", 28, UI.LIME, 8)
	col.add_child(_title_best)
	for c in col.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_loading = UI.label("TUNING THE JUNGLE...", 26, UI.PINK, 8)
	col.add_child(_loading)

	# --- how to play (built, but not on the title menu until the controls settle down)
	_howto = _panel_root()
	var hp := _centered_panel(_howto, Vector2(900, 600))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hp.add_child(hv)
	hv.add_child(UI.label("HOW TO PLAY", 48, UI.LIME, 12))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	hv.add_child(grid)
	var rows := [
		["A D  /  LEFT RIGHT", "Steer  (in the air: spin)"],
		["W S  /  UP DOWN", "Swim harder / brake  (in the air: front / back flip)"],
		["SPACE  (hold, release)", "Charge a leap. Hold it over a ramp or waterfall lip for big air"],
		["Q  E", "Corkscrew (barrel roll) in the air"],
		["J  K  L  I", "Grabs: Fin Grab, Tail Tweak, Gill Slap, Dorsal Stale"],
		["SHIFT", "Boost. Tricks and rings fill the meter"],
		["ESC", "Pause"],
	]
	for r: Array in rows:
		grid.add_child(UI.label(r[0], 24, UI.CYAN, 6))
		grid.add_child(UI.label(r[1], 24, Color.WHITE, 6))
	var tips := UI.label("Land upright, and let go of grabs before you hit the water.\n" +
			"Land ON THE BEAT for x1.5, PERFECT for x2. Keep landing tricks to build FLOW (up to x5).\n" +
			"Land on bamboo to grind. Bears swipe on the beat, so jump over them!\n" +
			"Gamepad: stick steers / flips, A jump, LT boost, LB RB corkscrew, X Y B RT grabs.\n" +
			"Touch: hold a finger down and the salmon swims to it. Swipe up to jump. In the air, swipe any way to spin or flip.", 21, UI.ORANGE, 6)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD
	tips.custom_minimum_size.x = 840
	hv.add_child(tips)
	hv.add_child(UI.button("BACK", _close_sub_panel))

	# --- options
	_options = _panel_root()
	var op := _centered_panel(_options, Vector2(640, 420))
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	op.add_child(ov)
	ov.add_child(UI.label("OPTIONS", 48, UI.LIME, 12))
	ov.add_child(_slider_row("MUSIC", Save.music_volume, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.music_volume = v
		Music.apply_volumes()))
	ov.add_child(_slider_row("SFX", Save.sfx_volume, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.sfx_volume = v
		Music.apply_volumes()))
	ov.add_child(_slider_row("PIXEL SIZE", Save.pixel_scale, 1.0, 5.0, 1.0, func(v: float) -> void:
		Save.pixel_scale = int(v)
		_container.stretch_shrink = int(v)))
	ov.add_child(UI.button("BACK", _close_sub_panel))

	# --- pause
	_pause = _panel_root()
	var pp := _centered_panel(_pause, Vector2(420, 360))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	pp.add_child(pv)
	pv.add_child(UI.label("PAUSED", 56, UI.LIME, 12))
	pv.add_child(UI.button("RESUME", _resume))
	pv.add_child(UI.button("RESTART", func() -> void: _start_race(_test_mode)))
	pv.add_child(UI.button("QUIT TO TITLE", _enter_title))

	# --- results
	_results = _panel_root()
	var rp := _centered_panel(_results, Vector2(760, 0))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rp.add_child(rv)
	_results_labels.title = UI.label("SPAWNED!", 48, UI.SALMON, 12)
	rv.add_child(_results_labels.title)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 30)
	rv.add_child(rrow)
	_results_labels.rank = UI.label("A", 150, UI.PINK, 18)
	rrow.add_child(_results_labels.rank)
	var rs := VBoxContainer.new()
	rrow.add_child(rs)
	rs.add_child(UI.label("SCORE", 26, UI.CYAN, 6))
	_results_labels.score = UI.label("0", 64, Color.WHITE, 12)
	rs.add_child(_results_labels.score)
	_results_labels.best = UI.label("", 28, UI.LIME, 8)
	rs.add_child(_results_labels.best)
	_results_labels.stats = UI.label("", 24, Color.WHITE, 6)
	rv.add_child(_results_labels.stats)
	_results_labels.route = UI.label("", 22, UI.ORANGE, 6)
	_results_labels.route.autowrap_mode = TextServer.AUTOWRAP_WORD
	_results_labels.route.custom_minimum_size.x = 700
	rv.add_child(_results_labels.route)
	var bh := GridContainer.new()
	bh.columns = 2
	bh.add_theme_constant_override("h_separation", 20)
	bh.add_theme_constant_override("v_separation", 8)
	rv.add_child(bh)
	_results_labels.next = UI.button("NEXT", func() -> void: _start_level(_next, _next_down))
	bh.add_child(_results_labels.next)
	_results_labels.alt = UI.button("OR", func() -> void: _start_level(_alt, false))
	bh.add_child(_results_labels.alt)
	bh.add_child(UI.button("SWIM AGAIN", func() -> void:
		_journey -= score.score
		_start_race()))
	bh.add_child(UI.button("TITLE", _enter_title))


const MAP_NODE := Vector2(206, 60)
## columns by lane: the northern wild route, the southern one, then the man-made one
const MAP_COLUMNS := [0, 2, 1]


## The map: a globe with every stage pinned on it, and the stages listed beside it tier by
## tier (one column per route). Point at a stage and the globe turns to it, drawing the way
## there; pick it to start a run from that stage.
func _build_levels() -> void:
	_levels = _panel_root()
	var lp := _centered_panel(_levels, Vector2(1200, 0))
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lp.add_child(lv)
	_map_title = UI.label("", 40, UI.LIME, 12)
	lv.add_child(_map_title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	lv.add_child(body)
	_map_globe = Globe.new()
	_map_globe.custom_minimum_size = Vector2(470, 470)
	body.add_child(_map_globe)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	list.add_child(head)
	var titles := ["NORTHERN (WILD)", "SOUTHERN (WILD)", "MAN-MADE"]
	for k in 3:
		var l := UI.label(titles[k], 18, Globe.LANE_COLORS[MAP_COLUMNS[k]], 6)
		l.custom_minimum_size.x = MAP_NODE.x
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	_level_buttons.resize(Levels.LIST.size())
	for tier in Levels.LAST_TIER + 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		for lane: int in MAP_COLUMNS:
			var id := Levels.at(tier, lane)
			if id == -1:
				var gap := Control.new()
				gap.custom_minimum_size = MAP_NODE
				row.add_child(gap)
				continue
			var b := UI.button("", func() -> void: _start_journey(id, _map_down))
			b.custom_minimum_size = MAP_NODE
			b.add_theme_font_size_override("font_size", 18)
			b.focus_entered.connect(_map_point.bind(id))
			b.mouse_entered.connect(_map_point.bind(id))
			row.add_child(b)
			_level_buttons[id] = b
	var legend := UI.label("MEET A STAGE'S GOAL TO STAY WILD. MISS IT AND YOU ARE SWEPT ONTO THE MAN-MADE ROUTE", 17, UI.ORANGE, 6)
	list.add_child(legend)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 20)
	lv.add_child(row2)
	_map_start = UI.button("", func() -> void: _start_journey(_map_first(), _map_down))
	row2.add_child(_map_start)
	_map_flip = UI.button("", func() -> void:
		_map_down = not _map_down
		_refresh_map())
	_map_flip.custom_minimum_size.x = 420
	row2.add_child(_map_flip)
	row2.add_child(UI.button("BACK", _close_sub_panel))
	# the travel screen, shown between stages: the red line crosses the globe to the next one
	_travel = _panel_root()
	var tp := _centered_panel(_travel, Vector2(860, 0))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tp.add_child(tv)
	_travel_label = UI.label("", 40, UI.CYAN, 12)
	_travel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_travel_label)
	var holder := CenterContainer.new()
	tv.add_child(holder)
	_travel_globe = Globe.new()
	_travel_globe.custom_minimum_size = Vector2(400, 400)
	holder.add_child(_travel_globe)
	_travel_tag = UI.label("", 26, UI.ORANGE, 8)
	_travel_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_travel_tag)


## Where a whole leg starts: the ocean going up, the lake coming down.
func _map_first() -> int:
	return Levels.at(Levels.LAST_TIER, 0) if _map_down else Levels.at(0, 0)


## Turns the map's globe to a stage and draws the last hop of the way there.
func _map_point(id: int) -> void:
	var path := Levels.path_to(id)
	if _map_down:
		# coming down, the way to a stage is from the spawning grounds above it
		path = Levels.path_from_top(id)
	var from := path[path.size() - 2] if path.size() > 1 else -1
	path.resize(path.size() - 1)
	_map_globe.show_path(path, from, id, 0.7)


func _refresh_map() -> void:
	_map_title.text = "%s  //  %s" % [_leg_name(_map_down), "SPRING, DOWNSTREAM" if _map_down else "AUTUMN, UPSTREAM"]
	_map_start.text = "START FROM THE LAKE" if _map_down else "START FROM THE OCEAN"
	_map_flip.text = "SHOW THE WAY UP" if _map_down else "SHOW THE WAY BACK DOWN"
	for i in _level_buttons.size():
		var key := i + (100 if _map_down else 0)
		var best := "%s (%s)" % [Hud.fmt(Save.best(key)), Save.rank(key)] if Save.best(key) > 0 else "-"
		_level_buttons[i].text = "%s\n%s" % [Levels.LIST[i].name, best]


func _open_levels() -> void:
	_map_down = _down
	_refresh_map()
	_map_globe.look_at_stage(_level)
	_show(_levels)
	_level_buttons[_level].grab_focus()


func _panel_root() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = UI.theme()
	c.visible = false
	_menus.add_child(c)
	_panels.append(c)
	return c


func _centered_panel(parent: Control, size: Vector2) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = size
	center.add_child(p)
	return p


func _slider_row(text: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UI.label(text, 28, UI.CYAN, 6)
	l.custom_minimum_size.x = 200
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(320, 32)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row


func _show(panel: Control) -> void:
	for c in _panels:
		c.visible = c == panel
	if panel:
		_focus_first(panel)


func _focus_first(node: Node) -> bool:
	for child in node.get_children():
		if child is Button or child is HSlider:
			(child as Control).grab_focus()
			return true
		if _focus_first(child):
			return true
	return false


func _open_sub_panel(panel: Control) -> void:
	_show(panel)


func _close_sub_panel() -> void:
	Save.store()
	_show(_title)


# ================================================================== autotest

func _autotest(delta: float) -> void:
	if _autotest_done:
		return
	_autotest_t += delta
	if phase == Phase.TITLE:
		if _autotest_t > 4.0 and _next_shot >= 0.0 and Music.is_ready:
			_next_shot = -1.0
			await _shot()
			print("AUTOTEST fps=%d" % Engine.get_frames_per_second())
			_start_race(_test_mode)
			_next_shot = _autotest_t + 3.0
		return
	if _autotest_t > _next_shot and not _results.visible:
		_next_shot = _autotest_t + 3.5
		print("AUTOTEST t=%.1f s=%.0f state=%d speed=%.1f score=%d fps=%d" % [race_time, world.player.s, world.player.state, world.player.speed, score.score, Engine.get_frames_per_second()])
		_shot()
	if _results.visible or _autotest_t > (70.0 if _test_mode else 200.0):
		_autotest_done = true
		await _shot()
		print("AUTOTEST DONE")
		get_tree().quit()


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%02d.png" % [_autotest_dir, _shots])
	_shots += 1
