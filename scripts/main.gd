extends Node
## Game flow: title -> countdown -> race -> results. Also owns the pixelated render target,
## the HUD and all menus.
##
## Run with `-- --autotest=<dir>` to play a race on autopilot, save screenshots to <dir>
## and print a summary (used for automated smoke tests).

const World := preload("res://scripts/world/world.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Score := preload("res://scripts/game/score.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const ChaseCam := preload("res://scripts/world/chase_camera.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

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
	_menus = CanvasLayer.new()
	_menus.layer = 5
	add_child(_menus)
	_build_menus()

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
	_title_best.text = "BEST  %s  (%s)" % [Hud.fmt(Save.best_score), Save.best_rank] if Save.best_score > 0 else ""


func _start_race() -> void:
	get_tree().paused = false
	_show(null)
	hud.visible = true
	hud.set_best(Save.best_score)
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
	Music.play_race()
	phase = Phase.COUNTDOWN


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


func _finish() -> void:
	phase = Phase.FINISHED
	hud.popup("FINISH!", UI.LIME, 2.5)
	Sfx.play("combo")
	world.player.control = false
	_finish_timer = 2.5


func _show_results() -> void:
	var rank := Score.rank_for(score.score)
	var new_best := _autotest_dir == "" and Save.submit_score(score.score, rank)
	# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score.score, true)
	var l: Dictionary = _results_labels
	(l.rank as Label).text = rank
	(l.score as Label).text = Hud.fmt(score.score)
	(l.best as Label).text = "NEW BEST!" if new_best else "BEST  %s" % Hud.fmt(Save.best_score)
	(l.stats as Label).text = "\n".join([
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
	elif _howto.visible or _options.visible:
		_close_sub_panel()


func _input(event: InputEvent) -> void:
	# Show the on-screen controls for whichever the player is actually using
	if event is InputEventScreenTouch:
		_use_touch = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_use_touch = false


func _process(delta: float) -> void:
	var p := world.player
	_touch.visible = _use_touch and phase in [Phase.COUNTDOWN, Phase.RACE] and not get_tree().paused
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
			if phase == Phase.RACE and p.s >= world.track.finish_s:
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
	col.position = Vector2(70, 70)
	col.add_theme_constant_override("separation", 14)
	_title.add_child(col)
	var t1 := UI.label("SALMON RUN 2", 118, UI.SALMON, 22)
	col.add_child(t1)
	col.add_child(UI.label("JUNGLE FALLS   //   174 BPM", 34, UI.CYAN, 10))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	col.add_child(spacer)
	col.add_child(UI.button("SWIM!", _start_race))
	col.add_child(UI.button("HOW TO PLAY", func() -> void: _open_sub_panel(_howto)))
	col.add_child(UI.button("OPTIONS", func() -> void: _open_sub_panel(_options)))
	if not OS.has_feature("web"):
		col.add_child(UI.button("QUIT", func() -> void: get_tree().quit()))
	_title_best = UI.label("", 28, UI.LIME, 8)
	col.add_child(_title_best)
	_loading = UI.label("TUNING THE JUNGLE...", 26, UI.PINK, 8)
	col.add_child(_loading)

	# --- how to play
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
			"Touch: drag the left side to steer and flip, hold + release JUMP, and GRAB, TWEAK, ROLL, BOOST.", 21, UI.ORANGE, 6)
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
	pv.add_child(UI.button("RESTART", _start_race))
	pv.add_child(UI.button("QUIT TO TITLE", _enter_title))

	# --- results
	_results = _panel_root()
	var rp := _centered_panel(_results, Vector2(760, 0))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rp.add_child(rv)
	rv.add_child(UI.label("SPAWNED!", 56, UI.SALMON, 12))
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
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 20)
	rv.add_child(bh)
	bh.add_child(UI.button("SWIM AGAIN", _start_race))
	bh.add_child(UI.button("TITLE", _enter_title))


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
			_start_race()
			_next_shot = _autotest_t + 3.0
		return
	if _autotest_t > _next_shot and not _results.visible:
		_next_shot = _autotest_t + 3.5
		print("AUTOTEST t=%.1f s=%.0f state=%d speed=%.1f score=%d fps=%d" % [race_time, world.player.s, world.player.state, world.player.speed, score.score, Engine.get_frames_per_second()])
		_shot()
	if _results.visible or _autotest_t > 200.0:
		_autotest_done = true
		await _shot()
		print("AUTOTEST DONE")
		get_tree().quit()


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%02d.png" % [_autotest_dir, _shots])
	_shots += 1
