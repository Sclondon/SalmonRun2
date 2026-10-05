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
const ModelViewer := preload("res://scripts/ui/model_viewer.gd")

const PRACTICE_HINT := "DRAG: STEER      SWIPE UP: JUMP      SWIPE DOWN: DIVE      WIGGLE OR CIRCLE: BOOST\nIN THE AIR: SWIPE TO SPIN / FLIP, CIRCLE TO CORKSCREW      JUMP UP THE WATERFALL"

enum Phase { TITLE, COUNTDOWN, RACE, FINISHED, CUTSCENE }

## How long each caption of a cutscene stays up.
const CAPTION_TIME := 3.4
## Before a run: the call home.
const INTRO := [
	"THE NORTH PACIFIC. TWO YEARS AT SEA.",
	"YOU HAVE GROWN FAT AND SILVER ON THE OPEN OCEAN.",
	"NOW SOMETHING IS CALLING YOU BACK:",
	"THE RIVER WHERE YOU HATCHED.",
	"SWIM HOME.",
]
## The end of the way up, at a home lake...
const SPAWNING := [
	"HOME. THE WATER YOU WERE BORN IN.",
	"SHE DIGS A NEST IN THE GRAVEL: A REDD.",
	"THE EGGS ARE LAID. BOTH PARENTS DIE HERE,",
	"AND THEIR BODIES FEED THE RIVER.",
	"IN SPRING, THEIR YOUNG SWIM FOR THE SEA.",
]
## ...or at a fish farm.
const FARMED := [
	"NOT HOME. A PEN, AND PELLETS.",
	"THE EGGS ARE TAKEN AND RAISED IN TRAYS.",
	"IT IS NOT THE RIVER, BUT IT IS A BEGINNING.",
	"IN SPRING, THE YOUNG ARE LET GO TO THE SEA.",
]
## The end of the run: the young reach the ocean.
const OUTRO := [
	"THE OPEN OCEAN AT LAST.",
	"SMALL, SILVER AND HUNGRY.",
	"TWO YEARS OF FEEDING LIE AHEAD.",
	"AND THEN, ONE AUTUMN,",
	"SOMETHING WILL CALL IT HOME.",
]

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
var _guide: Control
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
## Practising on the training course (one of everything) rather than on a stage
var _drill := true
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
## After a stage on the way up: the ways on that are open to choose between on the globe
var _ways: Array[int] = []
## ...and the ones that stayed shut because the stage's goal was missed
var _shut: Array[int] = []
var _travel_go: Button
var _pause_quit: Button
var _travel_globe: Globe
## The stage the run has just come from (-1 at the start of one), for the line on the globe
var _from := -1
var _travel: Control
var _pv_wrap: Control
var _pv_buttons: HBoxContainer
var _pv_arrows: Array[Button] = []
## Tester mode: the stage NEW RUN will start on, the pause menu's skip buttons, and a goal
## result forced by them (1 met, -1 missed, 0 as played)
var _start_at := 0
## The globe is being used to pick a stage to practise (-1 in _start_at is the training
## course), and whether that is on the way down
var _practising := false
var _practice_down := false
var _pv_way: Button
var _skip_buttons: Array[Button] = []
var _forced_goal := 0
## Cutscenes: the captions, what happens afterwards, the clock, and the scene's own widgets
var _cut_lines: Array = []
var _cut_done: Callable
var _cut_t := 0.0
var _cut: Control
var _cut_caption: Label
## NEW RUN has just been started from the ocean: play the intro before the first countdown
var _intro_due := false
## Every stage finished on this run, for the page at the end: {name, down, score, rank}
var _log: Array[Dictionary] = []
var _summary: Control
var _summary_labels := {}
var _travel_back: Button
## NEW RUN is waiting on its START button (rather than a way on being chosen)
var _starting := false
## The little window on the stage in hand
var _pv_card: PanelContainer
var _pv_image: TextureRect
var _pv_name: Label
var _pv_line: Label
var _pv_where: Label
var _pv_kicker: Label
var _pv_ask: Label
var _muffled := false
var _title_head: VBoxContainer
var _title_menu: VBoxContainer
var _busy := false

var _autotest_dir := ""
## `--practice` on the command line: the smoke test runs the training course
var _arg_practice := false
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
			_arg_practice = true
		elif arg == "--touch-ui":
			_use_touch = true
	_use_touch = _use_touch or DisplayServer.is_touchscreen_available()

	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_apply_filter()
	var post := ShaderMaterial.new()
	post.shader = preload("res://shaders/post.gdshader")
	_container.material = post
	_apply_filter()
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
	_build_globe()
	_level = Save.level
	_down = Save.down

	var p := world.player
	p.trick_landed.connect(_on_trick)
	p.wiped_out.connect(_on_wipe)
	p.bumped.connect(_on_bump)
	p.ring_collected.connect(_on_ring)
	p.jumped.connect(_on_jump)
	p.landed.connect(_on_land)
	p.dived.connect(func(_down: bool) -> void: _sfx("splash", 1.4, -8.0))
	Music.beat.connect(_on_beat)
	_enter_title()


# ================================================================== flow

func _enter_title() -> void:
	if _test_mode:
		# practice borrows the stage and direction; the journey picks up where it was left
		_test_mode = false
		_level = Save.level
		_down = Save.down
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
	_title_sub.visible = false
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
func _start_journey(index: int, down: bool, route: Array[int] = []) -> void:
	_route = route.duplicate()
	_journey = 0
	_log.clear()
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
	if _forced_goal != 0:
		return _forced_goal > 0 and _has_objective()
	if not _has_objective():
		return false
	var o: Dictionary = Levels.LIST[_level].objective
	return _objective_value() <= int(o.n) if o.type == "clean" else _objective_value() >= int(o.n)


func _start_race(test := false) -> void:
	if _busy:
		return
	# practice is either the training course or any stage, swum with no countdown or finish
	var drill := test and _drill
	if not world.has_course(_level, drill, _down):
		# building a level takes a moment: say where we're going, then let that frame draw first
		_busy = true
		hud.visible = false
		_travel_go.visible = true
		_pv_buttons.visible = false
		_pv_way.visible = false
		_travel_globe.show_all = false
		_travel_globe.stop_choosing()
		var stage := Levels.RAINFOREST if drill else _level
		var done: Array[int] = []
		if not _down and not test:
			done = _route.duplicate()
		if _from == -1 or _from == stage or not _travel.visible:
			_travel_globe.look_at_stage(stage)
		_travel_globe.show_path(done, -1 if test else _from, stage, 1.3)
		_preview(stage, "ONE OF EVERYTHING, FOR TRYING THE CONTROLS" if drill else "")
		_show(_travel)
		Music.set_filter(700.0)
		if not test and _from != -1 and _from != _level:
			# let the line reach the next stage before the screen freezes to build it
			await get_tree().create_timer(1.6).timeout
		await get_tree().process_frame
		await get_tree().process_frame
		_busy = false
	_test_mode = test
	world.set_course(_level, drill, _down)
	_touch.hint = PRACTICE_HINT if test else ""
	GameInput.clear_touch()
	get_tree().paused = false
	_show(null)
	hud.visible = true
	hud.set_best(0 if test else Save.best(_key()))
	score.reset()
	_forced_goal = 0
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
	if _intro_due and not test and _autotest_dir == "":
		_intro_due = false
		_cutscene(INTRO, _begin_stage.bind(test, drill))
	else:
		_begin_stage(test, drill)


## The stage proper: its tune from the top, then the countdown (practice just starts).
func _begin_stage(test: bool, drill: bool) -> void:
	var p := world.player
	hud.visible = true
	_show(null)
	Music.play_race(Levels.LIST[Levels.RAINFOREST if drill else _level].tier)
	phase = Phase.COUNTDOWN
	if not test:
		hud.popup(Levels.LIST[_level].name, UI.TEAL, 2.6)
	if test:
		# no countdown, no finish line: just swim
		phase = Phase.RACE
		p.control = not p.autopilot
		p.go()


# ================================================================== cutscenes

## Plays a few captions over the stage that is loaded, filmed by the title screen's roving
## camera with the salmon swimming on its own, then calls `done`. Any press skips it.
func _cutscene(lines: Array, done: Callable) -> void:
	_cut_lines = lines
	_cut_done = done
	_cut_t = 0.0
	phase = Phase.CUTSCENE
	get_tree().paused = false
	hud.visible = false
	_cut_caption.text = ""
	_show(_cut)
	var p := world.player
	p.reset(Track.START_S)
	p.autopilot = true
	p.control = false
	p.go()
	world.track.reset_rings()
	world.camera.mode = ChaseCam.Mode.CINEMA
	world.camera.snap()


func _end_cutscene() -> void:
	if phase != Phase.CUTSCENE:
		return
	phase = Phase.TITLE
	var p := world.player
	p.reset(Track.START_S)
	p.autopilot = _autotest_dir != ""
	world.track.reset_rings()
	world.camera.mode = ChaseCam.Mode.FOLLOW
	world.camera.snap()
	_cut_done.call()


func _run_cutscene(delta: float) -> void:
	_cut_t += delta
	var index := int(_cut_t / CAPTION_TIME)
	if index >= _cut_lines.size():
		_end_cutscene()
		return
	# each caption fades in, holds and fades out
	var at := fmod(_cut_t, CAPTION_TIME)
	_cut_caption.text = _cut_lines[index]
	_cut_caption.modulate.a = minf(smoothstep(0.0, 0.5, at), 1.0 - smoothstep(CAPTION_TIME - 0.5, CAPTION_TIME, at))
	var p := world.player
	if p.s > world.track.finish_s + 60.0:
		p.reset(Track.START_S)
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
	hud.popup("ONE MORE LAP", UI.GOLD, 1.0)


func _finish() -> void:
	phase = Phase.FINISHED
	hud.popup("FINISH!", UI.GOLD, 2.5)
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
	_log.append({"name": Levels.LIST[_level].name, "down": _down, "score": score.score, "rank": rank})
	var l: Dictionary = _results_labels
	var stage: Dictionary = Levels.LIST[_level]
	var title := "%s CLEARED" % stage.name
	var route := ""
	_next = -1
	_ways.clear()
	_shut.clear()
	_next_down = _down
	var next_text := ""
	if _down:
		_next = Levels.prev_down(_level, _route)
		if _next == -1:
			title = "THE OPEN OCEAN"
			next_text = "CONTINUE"
			route = "THE YOUNG HAVE REACHED THE SEA"
	else:
		if _route.is_empty() or _route[-1] != _level:
			_route.append(_level)
		var met := _objective_met()
		var options := Levels.next_up(_level, met)
		if options.is_empty():
			# the end of the run up: spawn, and the young take it from here
			title = stage.get("ending", "HOME AT LAST. SPAWNED!")
			route = "THE ADULTS DIE HERE AND FEED THE RIVER. THEIR YOUNG HEAD FOR THE SEA"
			_next = _level
			_next_down = true
			next_text = "THE NEXT GENERATION"
		else:
			_ways = options
			for way in Levels.next_of(_level):
				if not _ways.has(way):
					_shut.append(way)
			next_text = "CHOOSE YOUR WAY" if _ways.size() > 1 else "CONTINUE"
			if _has_objective():
				route = "GOAL MET: THE ADVANCED ROUTE IS OPEN" if met else "GOAL MISSED (%s): THE DEFAULT ROUTE IT IS" % Levels.objective_text(_level)
	if next_text == "" and _next != -1:
		next_text = "NEXT: %s" % Levels.LIST[_next].name
	(l.title as Label).text = title
	(l.route as Label).text = route
	(l.route as Label).visible = route != ""
	(l.route as Label).add_theme_color_override("font_color", Color(0.12, 0.45, 0.22) if route.begins_with("GOAL MET") else UI.RED)
	hud.visible = false
	(l.leg as Label).text = "FIELD REPORT   ·   %s" % _leg_name(_down)
	(l.next as Button).text = next_text
	l.rank_text = rank
	(l.stamp as Control).queue_redraw()
	(l.journey as Label).text = "THE RUN SO FAR   %s" % Hud.fmt(_journey)
	(l.score as Label).text = Hud.fmt(score.score)
	(l.best as Label).text = "NEW BEST!" if new_best else "BEST  %s" % Hud.fmt(Save.best(_key()))
	(l.keys as Label).text = "TIME\nTRICKS\nON THE BEAT\nBEST TRICK\nBEST FLOW\nRINGS\nWIPEOUTS"
	(l.stats as Label).text = "\n".join([
		Hud.fmt_time(race_time),
		str(score.tricks),
		str(score.on_beats),
		"%s  (%s)" % [score.best_trick.to_upper(), Hud.fmt(score.best_trick_pts)] if score.best_trick != "" else "-",
		"x%d" % score.best_flow,
		str(score.rings),
		str(score.wipeouts),
	])
	_show(_results)
	if _autotest_dir != "":
		print("AUTOTEST RESULT score=%d rank=%s time=%.1f tricks=%d on_beat=%d rings=%d wipeouts=%d best='%s'" % [
			score.score, rank, race_time, score.tricks, score.on_beats, score.rings, score.wipeouts, score.best_trick])
		print("AUTOTEST ROUTE title='%s' next=%s ways=%s down=%s note='%s'" % [title, Levels.LIST[_next].name if _next != -1 else "-", ", ".join(_ways.map(func(a: int) -> String: return Levels.LIST[a].name)), _next_down, route])


## Leaving from the pause menu: a run goes back to the title, practice back to its map.
func _quit_from_pause() -> void:
	var practice := _test_mode
	var stage := _level
	var down := _down
	_enter_title()
	if practice:
		_open_practice(-1 if _drill else stage, down)


## From the results screen: on to the next stage, by way of the globe when there is a way on
## to pick (the way up), straight there otherwise.
func _continue() -> void:
	if _ways.is_empty():
		if _next == -1:
			# the young have reached the ocean: the end of the run
			_cutscene(OUTRO, _show_summary)
		elif _next_down and not _down:
			# the end of the way up: spawning, then the next generation sets off
			var farm: bool = Levels.settings(_level).get("farm", false)
			_cutscene(FARMED if farm else SPAWNING, _start_level.bind(_next, true))
		else:
			_start_level(_next, _next_down)
		return
	_travel_globe.look_at_stage(_level)
	_travel_globe.choose(_route, _level, _ways, _shut)
	_preview(_ways[0])
	_starting = false
	_practising = false
	_pv_way.visible = false
	_travel_globe.show_all = false
	_travel_go.text = "SWIM"
	_travel_go.visible = true
	_pv_buttons.visible = true
	hud.visible = false
	_show(_travel)
	_travel_go.grab_focus()


## NEW RUN: the globe, looking at the open ocean where every run begins. Nothing starts
## until you say so.
func _open_run() -> void:
	_route.clear()
	_journey = 0
	_level = Levels.START
	_down = false
	_from = -1
	_travel_globe.stop_choosing()
	_start_at = Levels.START
	_travel_globe.look_at_stage(Levels.START)
	_travel_globe.show_path([], -1, Levels.START)
	_preview(Levels.START)
	_starting = true
	_practising = false
	_pv_way.visible = false
	_travel_globe.show_all = false
	_travel_go.text = "START"
	_travel_go.visible = true
	_pv_buttons.visible = true
	_show(_travel)
	_travel_go.grab_focus()


## The big button on the globe: begin the run, or swim the way that is highlighted.
func _go() -> void:
	if _practising:
		_practising = false
		_drill = _start_at == -1
		if not _drill:
			_level = _start_at
			_down = _practice_down
		_from = -1
		_start_race(true)
		return
	if _starting:
		# (a tester may have picked a later stage: the run then begins as if it had come the
		# usual way to it)
		var before := Levels.path_to(_start_at)
		before.resize(before.size() - 1)
		# the story opens every run that begins where the story does
		_intro_due = _start_at == Levels.START
		_start_journey(_start_at, false, before)
	else:
		_take_way(_travel_globe.choices[_travel_globe.choice])


func _take_way(id: int) -> void:
	_start_level(id, false)


## The card beside the globe: what a stage looks like, where it is, and a fact about the
## salmon at that point of its life.
func _preview(id: int, line := "") -> void:
	var stage: Dictionary = Levels.LIST[id]
	_pv_name.text = stage.name
	var at: Vector2 = stage.at
	_pv_where.text = "%.1f°%s  %.1f°%s" % [absf(at.x), "N" if at.x >= 0.0 else "S", absf(at.y), "E" if at.y >= 0.0 else "W"]
	# a true thing about the salmon at this point: the adult on the way up, the young on the
	# way back down
	var down := _practice_down if _practising else _down
	var fact: String = Levels.DOWN_FACTS[int(stage.tier)] if down else str(stage.fact)
	_pv_line.text = line if line != "" else fact
	_pv_ask.text = "Did you know?" if line == "" else "Practice"
	_pv_kicker.text = "TRAINING" if line != "" else "STAGE %d: %s" % [int(stage.tier) + 1, "SPRING, SEAWARD" if down else "AUTUMN, HOMEWARD"]
	var path := "res://textures/previews/%s.png" % str(stage.name).to_lower().replace(" ", "_")
	_pv_image.texture = load(path) if ResourceLoader.exists(path) else null


## Pushes the picture options (Save) to the low-res view, its post-process and the wobble.
func _apply_filter() -> void:
	_container.stretch_shrink = Save.pixel_scale
	var post := _container.material as ShaderMaterial
	if post:
		post.set_shader_parameter("dither", Save.dither)
		post.set_shader_parameter("vignette", Save.vignette * 0.5)
	RenderingServer.global_shader_parameter_set("psx_wobble", Save.wobble)


## The arrows on the globe card: the next way on, or (tester mode, before a run) the next
## stage to start from.
func _step_way(dir: int) -> void:
	if not ((_starting and Save.tester) or _practising):
		_travel_globe.step(dir)
		return
	var order: Array[int] = []
	if _practising:
		order.append(-1)  # the training course
	for tier in Levels.tiers():
		order.append_array(Levels.on_tier(tier))
	_start_at = order[posmod(order.find(_start_at) + dir, order.size())]
	if _practising:
		_show_practice_stage()
		return
	var path := Levels.path_to(_start_at)
	var from := path[path.size() - 2] if path.size() > 1 else -1
	path.resize(path.size() - 1)
	_travel_globe.show_path(path, from, _start_at, 0.6)
	_preview(_start_at)


## Tester mode: finish the stage now, as if its goal had been met or missed.
func _skip_stage(met: bool) -> void:
	_forced_goal = 1 if met else -1
	_resume()
	_finish()


func _pause_game() -> void:
	get_tree().paused = true
	Music.set_filter(700.0)
	_pause_quit.text = "BACK TO THE MAP" if _test_mode else "QUIT TO TITLE"
	for b in _skip_buttons:
		b.visible = Save.tester and not _test_mode
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
	elif _travel.visible and _pv_buttons.visible:
		_globe_back()
	elif _howto.visible or _options.visible:
		_close_sub_panel()


func _input(event: InputEvent) -> void:
	# any press skips a cutscene (once it has had a moment, so the press that began it doesn't)
	if phase == Phase.CUTSCENE and _cut_t > 0.6 and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch):
		_end_cutscene()
		get_viewport().set_input_as_handled()
		return
	# Show the on-screen controls for whichever the player is actually using
	if event is InputEventScreenTouch:
		_use_touch = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_use_touch = false


func _process(delta: float) -> void:
	var p := world.player
	_touch.visible = phase in [Phase.COUNTDOWN, Phase.RACE] and not get_tree().paused and not _travel.visible
	_layout_globes()
	_layout_title()
	hud.set_touch_mode(_use_touch)
	_loading.visible = not Music.is_ready
	# under the water the picture swims and takes the colour of the water, and the music is
	# muffled
	var under: float = world.camera.submerged
	var post := _container.material as ShaderMaterial
	post.set_shader_parameter("underwater", under)
	post.set_shader_parameter("water_tint", world.track.cfg.get("water_shallow", Color(0.16, 0.7, 0.64)))
	if phase == Phase.RACE and (under > 0.5) != _muffled:
		_muffled = under > 0.5
		Music.set_filter(1100.0 if _muffled else 20000.0)
	match phase:
		Phase.CUTSCENE:
			_run_cutscene(delta)
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
				hud.popup("FLOW ENDED", UI.OCHRE, 0.8)
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
	Sfx.play(sound, pitch, db - (14.0 if phase in [Phase.TITLE, Phase.CUTSCENE] else 0.0))


func _on_trick(trick: Dictionary) -> void:
	if _autotest_dir != "":
		print("  trick: %s  +%d  beat=%d  (s=%.0f)" % [trick.name, trick.points, trick.beat, world.player.s])
	if phase != Phase.RACE:
		return
	var flow := score.flow
	var gained := score.add_trick(trick)
	world.player.boost = minf(world.player.boost + float(trick.points) / 40.0, 100.0)
	var grade := int(trick.get("grade", 0))
	hud.show_trick(trick.name, gained, flow, grade)
	# how well it was timed, from MISS up to PERFECT!
	hud.show_grade(grade, str(Score.GRADES[grade][0]))
	Sfx.play("trick", 1.0 + 0.06 * (flow - 1))
	if grade >= Score.ON_BEAT:
		Sfx.play("ding", 0.7 + 0.075 * (grade - Score.ON_BEAT))


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
	_title_sub = UI.label("", 34, UI.TEAL, 10)
	col.add_child(_title_sub)
	# the buttons are a block of their own, so that on a phone they can sit at the bottom of
	# the screen, under the thumb (see _layout_title)
	_title_head = col
	_title_menu = VBoxContainer.new()
	_title_menu.add_theme_constant_override("separation", 14)
	_title.add_child(_title_menu)
	col = _title_menu
	col.add_child(UI.button("NEW RUN", _open_run))
	col.add_child(UI.button("PRACTICE", func() -> void: _open_practice(_level, false)))
	col.add_child(UI.button("FIELD GUIDE", func() -> void: _open_sub_panel(_guide)))
	col.add_child(UI.button("OPTIONS", func() -> void: _open_sub_panel(_options)))
	if not OS.has_feature("web"):
		col.add_child(UI.button("QUIT", func() -> void: get_tree().quit()))
	_title_best = UI.label("", 28, UI.GOLD, 8)
	col.add_child(_title_best)
	for c in col.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_loading = UI.label("TUNING THE JUNGLE...", 26, UI.CORAL, 8)
	col.add_child(_loading)

	# --- how to play (built, but not on the title menu until the controls settle down)
	_howto = _panel_root()
	var hp := _centered_panel(_howto, Vector2(900, 600))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hp.add_child(hv)
	hv.add_child(UI.label("HOW TO PLAY", 48, UI.GOLD, 12))
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
		grid.add_child(UI.label(r[0], 24, UI.TEAL, 6))
		grid.add_child(UI.label(r[1], 24, Color.WHITE, 6))
	var tips := UI.label("Land upright, and let go of grabs before you hit the water.\n" +
			"Land on the beat: the closer, the better the grade, up to x2 for PERFECT! Keep landing tricks to build FLOW (up to x5).\n" +
			"Land on bamboo to grind. Bears swipe on the beat, so jump over them!\n" +
			"Gamepad: stick steers / flips, A jump, LT boost, LB RB corkscrew, X Y B RT grabs.\n" +
			"Touch: drag left or right to steer. Swipe up to jump. In the air, swipe any way to spin or flip.", 21, UI.OCHRE, 6)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD
	tips.custom_minimum_size.x = 840
	hv.add_child(tips)
	hv.add_child(UI.button("BACK", _close_sub_panel))

	# --- the field guide: the models, to look at
	_guide = _panel_root()
	var viewer := ModelViewer.new()
	viewer.closed.connect(_close_sub_panel)
	_guide.add_child(viewer)

	# --- options
	_options = _panel_root()
	var op := _centered_panel(_options, Vector2(640, 420))
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	op.add_child(ov)
	ov.add_child(UI.label("OPTIONS", 48, UI.GOLD, 12))
	ov.add_child(_slider_row("MUSIC", Save.music_volume, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.music_volume = v
		Music.apply_volumes()))
	ov.add_child(_slider_row("SFX", Save.sfx_volume, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.sfx_volume = v
		Music.apply_volumes()))
	# the retro filter, piece by piece (all the way left turns a piece off)
	ov.add_child(UI.label("PICTURE", 22, UI.TEAL, 6))
	ov.add_child(_slider_row("PIXEL SIZE", Save.pixel_scale, 1.0, 5.0, 1.0, func(v: float) -> void:
		Save.pixel_scale = int(v)
		_apply_filter()))
	ov.add_child(_slider_row("COLOUR DITHER", Save.dither, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.dither = v
		_apply_filter()))
	ov.add_child(_slider_row("WOBBLE", Save.wobble, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.wobble = v
		_apply_filter()))
	ov.add_child(_slider_row("DARK CORNERS", Save.vignette, 0.0, 1.0, 0.05, func(v: float) -> void:
		Save.vignette = v
		_apply_filter()))
	var tester := {}
	tester.b = UI.button("", func() -> void:
		Save.tester = not Save.tester
		(tester.b as Button).text = "TESTER MODE: %s" % ("ON" if Save.tester else "OFF"))
	(tester.b as Button).text = "TESTER MODE: %s" % ("ON" if Save.tester else "OFF")
	ov.add_child(tester.b)
	ov.add_child(UI.button("BACK", _close_sub_panel))

	# --- pause
	_pause = _panel_root()
	var pp := _centered_panel(_pause, Vector2(420, 360))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	pp.add_child(pv)
	pv.add_child(UI.label("PAUSED", 56, UI.GOLD, 12))
	pv.add_child(UI.button("RESUME", _resume))
	pv.add_child(UI.button("RESTART", func() -> void: _start_race(_test_mode)))
	pv.add_child(UI.button("OPTIONS", func() -> void: _open_sub_panel(_options)))
	# tester mode: jump to the end of the stage, with its goal met or missed
	for met: bool in [true, false]:
		var skip := UI.button("SKIP: GOAL MET" if met else "SKIP: GOAL MISSED", _skip_stage.bind(met))
		skip.add_theme_font_size_override("font_size", 22)
		pv.add_child(skip)
		_skip_buttons.append(skip)
	_pause_quit = UI.button("QUIT TO TITLE", _quit_from_pause)
	pv.add_child(_pause_quit)

	# --- results: a field report on a sheet of paper, with the rank stamped on it
	_results = _panel_root()
	var rv := _page(_results, 800)
	var r_head := _ink("", 18, UI.TEAL.darkened(0.45))
	_results_labels.leg = r_head
	rv.add_child(r_head)
	_results_labels.title = _ink("", 40, UI.INK, true)
	rv.add_child(_results_labels.title)
	rv.add_child(_rule())
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 34)
	rv.add_child(rrow)
	var stamp := Control.new()
	stamp.custom_minimum_size = Vector2(170, 170)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rrow.add_child(stamp)
	_results_labels.stamp = stamp
	stamp.draw.connect(func() -> void:
		# the rank, stamped a little askew in red ink
		stamp.draw_set_transform(Vector2(85, 85), -0.16, Vector2.ONE)
		stamp.draw_arc(Vector2.ZERO, 76.0, 0.0, TAU, 48, UI.RED, 7.0)
		stamp.draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, UI.RED, 2.5)
		var letter: String = _results_labels.get("rank_text", "")
		var w := UI.serif().get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
		stamp.draw_string(UI.serif(), Vector2(-w * 0.5, 34.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, UI.RED))
	var rs := VBoxContainer.new()
	rs.add_theme_constant_override("separation", 0)
	rrow.add_child(rs)
	rs.add_child(_ink("SCORE", 18, UI.TEAL.darkened(0.45)))
	_results_labels.score = _ink("0", 60, UI.INK, true)
	rs.add_child(_results_labels.score)
	_results_labels.best = _ink("", 22, UI.RED)
	rs.add_child(_results_labels.best)
	_results_labels.journey = _ink("", 20, UI.INK)
	rs.add_child(_results_labels.journey)
	rv.add_child(_rule())
	# the figures, as a two-column table
	var table := HBoxContainer.new()
	table.add_theme_constant_override("separation", 30)
	rv.add_child(table)
	_results_labels.keys = _ink("", 21, UI.TEAL.darkened(0.45))
	table.add_child(_results_labels.keys)
	_results_labels.stats = _ink("", 21, UI.INK)
	table.add_child(_results_labels.stats)
	_results_labels.route = _ink("", 20, UI.RED)
	_results_labels.route.autowrap_mode = TextServer.AUTOWRAP_WORD
	_results_labels.route.custom_minimum_size.x = 740
	rv.add_child(_results_labels.route)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	rv.add_child(bh)
	_results_labels.next = UI.button("NEXT", _continue)
	bh.add_child(_results_labels.next)
	bh.add_child(UI.button("SWIM AGAIN", func() -> void:
		_journey -= score.score
		_log.pop_back()
		_start_race()))
	bh.add_child(UI.button("TITLE", _enter_title))
	for b: Button in bh.get_children():
		b.custom_minimum_size.x = 220

	# --- the end of a run: every stage of the life cycle on one page
	_summary = _panel_root()
	var sv := _page(_summary, 900)
	sv.add_child(_ink("THE LIFE CYCLE OF THE PACIFIC SALMON", 18, UI.TEAL.darkened(0.45)))
	_summary_labels.title = _ink("A FULL TURN OF THE CYCLE", 40, UI.INK, true)
	sv.add_child(_summary_labels.title)
	sv.add_child(_rule())
	var legs := HBoxContainer.new()
	legs.add_theme_constant_override("separation", 40)
	sv.add_child(legs)
	for leg: String in ["up", "down"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.custom_minimum_size.x = 410
		legs.add_child(column)
		column.add_child(_ink("SEAWARD MIGRATION  ·  SPRING" if leg == "down" else "SPAWNING MIGRATION  ·  AUTUMN", 18, UI.RED))
		_summary_labels[leg] = _ink("", 21, UI.INK)
		column.add_child(_summary_labels[leg])
	sv.add_child(_rule())
	_summary_labels.total = _ink("", 34, UI.INK, true)
	sv.add_child(_summary_labels.total)
	_summary_labels.note = _ink("", 20, UI.TEAL.darkened(0.45))
	sv.add_child(_summary_labels.note)
	var sb := HBoxContainer.new()
	sb.add_theme_constant_override("separation", 14)
	sv.add_child(sb)
	sb.add_child(UI.button("NEW RUN", _open_run))
	sb.add_child(UI.button("TITLE", _enter_title))

	# --- cutscenes: black bars top and bottom, and a caption on the lower one
	_cut = _panel_root()
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = UI.INK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 84
		else:
			bar.offset_top = -150
		_cut.add_child(bar)
	_cut_caption = UI.label("", 34, UI.PAPER, 0)
	_cut_caption.add_theme_font_override("font", UI.serif())
	_cut_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cut_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cut_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_cut_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_cut_caption.offset_top = -150
	_cut_caption.offset_left = 60
	_cut_caption.offset_right = -60
	_cut.add_child(_cut_caption)
	var skip := UI.label("PRESS ANYTHING TO SKIP", 16, Color(UI.PAPER, 0.55), 0)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-250, 30)
	_cut.add_child(skip)


## A sheet of cream paper in the middle of the screen, for the reports; returns the column
## its contents go in.
func _page(parent: Control, width: float) -> VBoxContainer:
	var sheet := _centered_panel(parent, Vector2(width, 0))
	var paper := UI.card(UI.PAPER, UI.INK, 3, 4)
	paper.set_content_margin_all(26)
	sheet.add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	sheet.add_child(column)
	return column


## Text printed on paper: dark, with no outline.
func _ink(text: String, size: int, col: Color, serif := false) -> Label:
	var l := UI.label(text, size, col, 0)
	l.add_theme_font_override("font", UI.serif() if serif else UI.font())
	return l


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = UI.GOLD.darkened(0.15)
	line.custom_minimum_size.y = 3
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The page at the end of a run: both legs stage by stage, and the total.
func _show_summary() -> void:
	var lines := {"up": [], "down": []}
	var total := 0
	for entry: Dictionary in _log:
		total += int(entry.score)
		(lines["down" if entry.down else "up"] as Array).append("%s   %s   %s" % [entry.rank, Hud.fmt(entry.score), entry.name])
	(_summary_labels.up as Label).text = "\n".join(lines.up) if not (lines.up as PackedStringArray).is_empty() else "-"
	(_summary_labels.down as Label).text = "\n".join(lines.down) if not (lines.down as PackedStringArray).is_empty() else "-"
	(_summary_labels.total as Label).text = "TOTAL   %s" % Hud.fmt(total)
	(_summary_labels.note as Label).text = "%d STAGES SWUM. THE YOUNG ARE AT SEA; IN TWO YEARS IT BEGINS AGAIN." % _log.size()
	phase = Phase.TITLE
	world.player.autopilot = true
	world.player.go()
	world.camera.mode = ChaseCam.Mode.CINEMA
	hud.visible = false
	_show(_summary)


## The globe scene: the map, the level select and the travel screen in one.
func _build_globe() -> void:
	# It is the whole screen, laid out after conceptArt/ui/levelSelect.png: the globe, and
	# over the lower part of it one framed card holding a picture of the stage in
	# hand, arrows either side to look at the other ways on, its name, a line about it and two
	# buttons.
	_travel = _panel_root()
	_travel_globe = Globe.new()
	_travel.add_child(_travel_globe)
	_pv_wrap = Control.new()
	_pv_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_travel.add_child(_pv_wrap)
	_pv_card = PanelContainer.new()
	# a page out of a school encyclopedia: cream paper with an ink border, and a gold rule
	# with a red diamond at each corner drawn just inside it
	var frame := UI.card(UI.PAPER, UI.INK, 2, 6)
	frame.set_content_margin_all(17)
	_pv_card.add_theme_stylebox_override("panel", frame)
	_pv_card.draw.connect(func() -> void:
		var inner := Rect2(Vector2(8, 8), _pv_card.size - Vector2(16, 16))
		_pv_card.draw_rect(inner, UI.OCHRE, false, 1.5)
		for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
			_pv_card.draw_colored_polygon(_diamond(corner, 5.0), UI.RED))
	_pv_wrap.add_child(_pv_card)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 7)
	_pv_card.add_child(pv)
	# the running head: which stage and season on the left, where on Earth on the right
	var head := PanelContainer.new()
	var head_frame := UI.flat(UI.NAVY, Color.TRANSPARENT, 0, 2)
	head_frame.content_margin_left = 10
	head_frame.content_margin_right = 10
	head_frame.content_margin_top = 2
	head_frame.content_margin_bottom = 2
	head.add_theme_stylebox_override("panel", head_frame)
	pv.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	_pv_kicker = UI.label("", 13, UI.PAPER, 0)
	_pv_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(_pv_kicker)
	_pv_where = UI.label("", 13, UI.GOLD, 0)
	head_row.add_child(_pv_where)
	# the picture, mounted like a plate: an ink line, a paper mat, the picture
	var window := PanelContainer.new()
	var window_frame := UI.flat(UI.PAPER, UI.INK, 2, 2)
	window_frame.set_content_margin_all(5)
	window.add_theme_stylebox_override("panel", window_frame)
	pv.add_child(window)
	_pv_image = TextureRect.new()
	_pv_image.custom_minimum_size = Vector2(416, 176)
	_pv_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pv_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pv_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.add_child(_pv_image)
	# its name as the caption, with the arrows to the other ways on either side of it. They
	# are drawn here rather than from a picture: navy discs with a paper chevron, that turn
	# gold while pressed (not under the pointer: on a phone that would leave the last one
	# tapped lit)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	pv.add_child(title)
	_pv_name = UI.label("", 23, UI.INK, 0)
	_pv_name.add_theme_font_override("font", UI.serif())
	_pv_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pv_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for dir: int in [-1, 1]:
		var arrow := Button.new()
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.custom_minimum_size = Vector2(44, 44)
		arrow.pressed.connect(func() -> void:
			Sfx.play("ui", 1.5, -6.0)
			_step_way(dir))
		arrow.draw.connect(func() -> void:
			var c := Vector2(22, 22)
			var down := arrow.is_pressed()
			arrow.draw_circle(c, 21.0, UI.INK)
			arrow.draw_circle(c, 19.0, UI.GOLD if down else UI.NAVY)
			arrow.draw_arc(c, 15.5, 0.0, TAU, 40, UI.INK if down else UI.OCHRE, 1.0, true)
			var tip := c + Vector2(6.0 * dir, 0.0)
			var back := c + Vector2(-4.0 * dir, 0.0)
			arrow.draw_polyline(PackedVector2Array([back + Vector2(0, -8), tip, back + Vector2(0, 8)]), UI.INK if down else UI.PAPER, 3.5, true))
		title.add_child(arrow)
		_pv_arrows.append(arrow)
		if dir == -1:
			title.add_child(_pv_name)
	# a rule with a diamond in the middle, as under a chapter heading
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 9)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void:
		var mid := rule.size * 0.5
		rule.draw_line(Vector2(0, mid.y), Vector2(mid.x - 10, mid.y), UI.OCHRE, 1.5)
		rule.draw_line(Vector2(mid.x + 10, mid.y), Vector2(rule.size.x, mid.y), UI.OCHRE, 1.5)
		rule.draw_colored_polygon(_diamond(mid, 4.5), UI.RED))
	pv.add_child(rule)
	# the fact, under the heading every school CD-ROM gave it
	var fact := VBoxContainer.new()
	fact.add_theme_constant_override("separation", 0)
	pv.add_child(fact)
	_pv_ask = UI.label("", 15, UI.RED, 0)
	_pv_ask.add_theme_font_override("font", UI.italic())
	fact.add_child(_pv_ask)
	_pv_line = UI.label("", 15, UI.INK, 0)
	_pv_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_pv_line.custom_minimum_size = Vector2(416, 44)
	fact.add_child(_pv_line)
	_pv_buttons = HBoxContainer.new()
	_pv_buttons.add_theme_constant_override("separation", 12)
	pv.add_child(_pv_buttons)
	_travel_back = UI.button("BACK", _globe_back)
	_travel_go = UI.button("", _go)
	# (on paper, a paper button wants to be a shade darker to stand off it)
	var manila := UI.card(Color(0.88, 0.83, 0.71), UI.INK, 2, 8)
	for b: Button in [_travel_back, _travel_go]:
		b.custom_minimum_size = Vector2(120, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", manila)
		_pv_buttons.add_child(b)
	# practice only: which leg of the journey to swim the stage on
	_pv_way = UI.button("", func() -> void:
		_practice_down = not _practice_down
		_show_practice_stage())
	_pv_way.add_theme_font_size_override("font_size", 20)
	_pv_way.add_theme_stylebox_override("normal", manila)
	_pv_way.custom_minimum_size.y = 40
	_pv_way.visible = false
	pv.add_child(_pv_way)
	_travel_globe.chosen.connect(_take_way)
	_travel_globe.pointed.connect(_preview)


## The title screen: the name at the top left with the buttons under it; on a phone held
## upright, the name across the top and the buttons, bigger, at the bottom under the thumb.
func _layout_title() -> void:
	var area := _title.size
	var head := _title_head.get_combined_minimum_size()
	var menu := _title_menu.get_combined_minimum_size()
	_title_head.size = head
	_title_menu.size = menu
	if area.y > area.x:
		var k := clampf((area.x - 140.0) / head.x, 1.0, 2.2)
		_title_head.scale = Vector2(k, k)
		_title_head.position = Vector2(70.0, 90.0)
		var kb := clampf((area.x - 200.0) / menu.x, 1.0, 2.4)
		_title_menu.scale = Vector2(kb, kb)
		_title_menu.position = Vector2((area.x - menu.x * kb) * 0.5, area.y - menu.y * kb - 150.0)
	else:
		_title_head.scale = Vector2.ONE
		_title_head.position = Vector2(70.0, 40.0)
		_title_menu.scale = Vector2.ONE
		_title_menu.position = Vector2(70.0, 40.0 + head.y + 14.0)


## Where the globe sits in each globe scene, after the concept art: the Earth behind, and the
## card across the bottom over the lower part of it. The same on a phone and on a desktop.
func _layout_globes() -> void:
	var area := _travel.size
	var tall := area.y > area.x
	var card := _pv_card.get_combined_minimum_size()
	_pv_card.size = card
	# the card: as wide as a phone allows, and a little over half the height of a wide screen
	var k := clampf((area.x - 90.0) / card.x, 1.0, 2.6) if tall else clampf(area.y * 0.5 / card.y, 0.6, 2.6)
	_pv_wrap.scale = Vector2(k, k)
	_travel_globe.ui_scale = maxf(k * 0.8, 1.0)
	_pv_wrap.size = card
	_pv_wrap.position = Vector2((area.x - card.x * k) * 0.5, area.y - card.y * k - (60.0 if tall else 20.0))
	var top := _pv_wrap.position.y
	if tall:
		# the globe is as big as the screen is wide, and the card comes up over the bottom
		# quarter of it
		var r := minf(area.x * 0.53, (top - 16.0) / 1.5)
		_travel_globe.radius = r / area.x
		_travel_globe.anchor = Vector2(0.5, (top - r * 0.5) / area.y)
	else:
		# the Earth is as big as leaves its top on the screen and the stage in hand (the
		# middle of the globe) in the clear above the card
		var middle := top - 40.0
		_travel_globe.radius = (middle - 18.0) / area.y
		_travel_globe.anchor = Vector2(0.5, middle / area.y)
	var several := _travel_globe.choices.size() > 1 or (_starting and Save.tester) or _practising
	for arrow in _pv_arrows:
		# (kept in the row when there is one way only, so that the card stays the same height)
		arrow.modulate.a = 1.0 if several else 0.0
		arrow.disabled = not several


## BACK on the globe: to the title before a run has started, to the results after a stage.
func _globe_back() -> void:
	_travel_globe.stop_choosing()
	_show(_title if _starting or _practising else _results)
	_practising = false


## PRACTICE: the same globe and card as a run, to pick any stage (or the training course)
## with the arrows. It shows no trail, since nothing has been swum.
func _open_practice(at: int, down: bool) -> void:
	_practising = true
	_starting = false
	_start_at = at
	_practice_down = down
	_travel_globe.stop_choosing()
	_travel_globe.show_all = true
	_travel_globe.look_at_stage(Levels.RAINFOREST if at == -1 else at)
	_show_practice_stage()
	_travel_go.text = "PRACTISE"
	_travel_go.visible = true
	_pv_buttons.visible = true
	hud.visible = false
	_show(_travel)
	_travel_go.grab_focus()


func _show_practice_stage() -> void:
	var stage := Levels.RAINFOREST if _start_at == -1 else _start_at
	_travel_globe.show_path([], -1, stage, 0.6)
	_preview(stage, "ONE OF EVERYTHING, FOR TRYING THE CONTROLS" if _start_at == -1 else "")
	if _start_at == -1:
		_pv_name.text = "TRAINING COURSE"
	_pv_way.visible = _start_at != -1
	_pv_way.text = "SPRING: THE WAY DOWN" if _practice_down else "AUTUMN: THE WAY UP"


func _diamond(at: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])


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
	var l := UI.label(text, 28, UI.TEAL, 6)
	l.custom_minimum_size.x = 250
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
	# options can be opened from the pause menu too: go back to wherever it came from
	_show(_pause if get_tree().paused else _title)


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
			_start_race(_arg_practice)
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
