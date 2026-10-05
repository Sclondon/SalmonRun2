extends SceneTree
## Takes the little pictures of each stage shown beside the globe (textures/previews/*.png):
## starts every stage in turn on autopilot, waits a few seconds and saves what the game
## camera sees. Run it (with a window: it needs the renderer) after changing how a stage looks:
##   godot --path . -s scripts/tools/bake_previews.gd
## then `godot --headless --path . --import` to import the new files.

const Levels := preload("res://scripts/world/levels.gd")

const WAIT := 6.5

var _main: Node
var _stage := -1
var _t := 0.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://textures/previews"))
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_t += delta
	if _stage == -1 and _t < 1.5:
		return false
	# count from when the stage is actually being swum (it has to be built first)
	if _stage != -1 and _main.phase != 2 and _main.phase != 1:
		_t = 0.0
	if _stage == -1 or _t > WAIT:
		if _stage != -1:
			# the 3D picture itself, before the HUD and menus are drawn over it
			var view: SubViewport = _main._container.get_child(0)
			var img := view.get_texture().get_image()
			img.resize(384, 216, Image.INTERPOLATE_NEAREST)
			var file := "res://textures/previews/%s.png" % str(Levels.LIST[_stage].name).to_lower().replace(" ", "_")
			img.save_png(ProjectSettings.globalize_path(file))
			print("saved ", file)
		_stage += 1
		if _stage >= Levels.LIST.size():
			return true
		_main._start_level(_stage, false, -1)
		_main.world.player.autopilot = true
		_t = 0.0
	return false
