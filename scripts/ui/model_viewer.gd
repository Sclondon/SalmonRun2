extends Control
## The field guide: a page from a school encyclopedia with a model on it that turns slowly (or
## is turned with a finger), its name, how big it really is and a fact about it. The arrows
## step through the salmon at each stage of its life, and then the other creatures it meets.

signal closed

const UI := preload("res://scripts/ui/ui_kit.gd")
const Props := preload("res://scripts/world/props.gd")

## Every page: what it is, its scientific name, its place in the book, how big it really is,
## a fact, which model, and how far back the camera has to stand to take it in.
const PAGES := [
	{"name": "FRY", "latin": "Oncorhynchus nerka", "kicker": "THE SOCKEYE, STAGE 1 OF 6", "length": "ABOUT 3 CM",
		"fact": "FRY WRIGGLE UP OUT OF THE GRAVEL ONCE THEIR YOLK SAC IS USED UP, AND START TO FEED.",
		"model": "fry", "reach": 1.7},
	{"name": "PARR", "latin": "Oncorhynchus nerka", "kicker": "THE SOCKEYE, STAGE 2 OF 6", "length": "ABOUT 7 CM",
		"fact": "A PARR WEARS DARK BARS DOWN ITS SIDES: CAMOUFLAGE FOR A YOUNG FISH IN FRESH WATER.",
		"model": "parr", "reach": 1.7},
	{"name": "SMOLT", "latin": "Oncorhynchus nerka", "kicker": "THE SOCKEYE, STAGE 3 OF 6", "length": "ABOUT 10 CM",
		"fact": "A SMOLT LOSES ITS BARS AND TURNS SILVER, AND ITS BODY CHANGES TO LIVE IN SALT WATER.",
		"model": "smolt", "reach": 1.7},
	{"name": "OCEAN ADULT", "latin": "Oncorhynchus nerka", "kicker": "THE SOCKEYE, STAGE 4 OF 6", "length": "ABOUT 60 CM",
		"fact": "A SOCKEYE DOES MOST OF ITS GROWING AT SEA, FEEDING ON PLANKTON AND KRILL.",
		"model": "ocean", "reach": 1.7},
	{"name": "MIGRATING ADULT", "latin": "Oncorhynchus nerka", "kicker": "THE SOCKEYE, STAGE 5 OF 6", "length": "ABOUT 60 CM",
		"fact": "BACK IN FRESH WATER IT STOPS FEEDING, AND ITS SILVER BEGINS TO TURN RED.",
		"model": "migrating", "reach": 1.7},
	{"name": "SPAWNER", "latin": "Oncorhynchus nerka", "kicker": "THE SOCKEYE, STAGE 6 OF 6", "length": "ABOUT 60 CM",
		"fact": "A SPAWNING MALE IS BRIGHT RED WITH A GREEN HEAD, A HUMPED BACK AND A HOOKED JAW.",
		"model": "spawner", "reach": 1.7},
	{"name": "SEA NETTLE", "latin": "Chrysaora fuscescens", "kicker": "IN THE SEA", "length": "BELL ABOUT 30 CM",
		"fact": "A SEA NETTLE TRAILS ITS STINGING TENTACLES SEVERAL METRES BEHIND IT.",
		"model": "nettle", "reach": 3.6},
	{"name": "DEEP-SEA JELLYFISH", "latin": "Scyphozoa", "kicker": "IN THE SEA", "length": "MANY KINDS",
		"fact": "MANY JELLYFISH OF THE DEEP SEA MAKE THEIR OWN LIGHT.",
		"model": "jelly", "reach": 1.6},
	{"name": "SALMON SHARK", "latin": "Lamna ditropis", "kicker": "IN THE SEA", "length": "ABOUT 2 M",
		"fact": "THE SALMON SHARK HUNTS PACIFIC SALMON, AND KEEPS ITS BODY WARMER THAN THE SEA ROUND IT.",
		"model": "shark", "reach": 2.9},
	{"name": "BROWN BEAR", "latin": "Ursus arctos", "kicker": "ON THE RIVER", "length": "ABOUT 2 M",
		"fact": "BEARS GATHER ON THE RIVER FOR THE SALMON RUN, AND CARRY WHAT IS LEFT INTO THE FOREST.",
		"model": "bear", "reach": 4.6},
]

var page := 0

var _card: PanelContainer
var _wrap: Control
var _kicker: Label
var _length: Label
var _name: Label
var _latin: Label
var _fact: Label
var _back: Button
var _view: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _models: Array[Node3D] = []
var _spin := 0.0
var _held := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(UI.NAVY.darkened(0.45), 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_wrap = Control.new()
	add_child(_wrap)
	_card = PanelContainer.new()
	var frame := UI.card(UI.PAPER, UI.INK, 2, 6)
	frame.set_content_margin_all(17)
	_card.add_theme_stylebox_override("panel", frame)
	_card.draw.connect(func() -> void:
		var inner := Rect2(Vector2(8, 8), _card.size - Vector2(16, 16))
		_card.draw_rect(inner, UI.OCHRE, false, 1.5)
		for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
			_card.draw_colored_polygon(_diamond(corner, 5.0), UI.RED))
	_wrap.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_card.add_child(col)
	# the running head: where it comes in the book on the left, how big it is on the right
	var head := PanelContainer.new()
	var head_frame := UI.flat(UI.NAVY, Color.TRANSPARENT, 0, 2)
	head_frame.content_margin_left = 10
	head_frame.content_margin_right = 10
	head_frame.content_margin_top = 2
	head_frame.content_margin_bottom = 2
	head.add_theme_stylebox_override("panel", head_frame)
	col.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	_kicker = UI.label("", 13, UI.PAPER, 0)
	_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(_kicker)
	_length = UI.label("", 13, UI.GOLD, 0)
	head_row.add_child(_length)
	# the plate: the model, in a window of its own
	var window := PanelContainer.new()
	var window_frame := UI.flat(UI.PAPER, UI.INK, 2, 2)
	window_frame.set_content_margin_all(5)
	window.add_theme_stylebox_override("panel", window_frame)
	col.add_child(window)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(440, 270)
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.stretch_shrink = 2
	holder.gui_input.connect(_on_plate_input)
	window.add_child(holder)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_DISABLED
	holder.add_child(_view)
	_build_stage()
	# its name, with the arrows either side
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	col.add_child(title)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UI.label("", 23, UI.INK, 0)
	_name.add_theme_font_override("font", UI.serif())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_name)
	_latin = UI.label("", 14, UI.TEAL.darkened(0.45), 0)
	_latin.add_theme_font_override("font", UI.italic())
	_latin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_latin)
	for dir: int in [-1, 1]:
		var arrow := Button.new()
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.custom_minimum_size = Vector2(44, 44)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.pressed.connect(func() -> void:
			Sfx.play("ui", 1.5, -6.0)
			step(dir))
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
		if dir == -1:
			title.add_child(names)
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 9)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void:
		var mid := rule.size * 0.5
		rule.draw_line(Vector2(0, mid.y), Vector2(mid.x - 10, mid.y), UI.OCHRE, 1.5)
		rule.draw_line(Vector2(mid.x + 10, mid.y), Vector2(rule.size.x, mid.y), UI.OCHRE, 1.5)
		rule.draw_colored_polygon(_diamond(mid, 4.5), UI.RED))
	col.add_child(rule)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	col.add_child(words)
	var ask := UI.label("Did you know?", 15, UI.RED, 0)
	ask.add_theme_font_override("font", UI.italic())
	words.add_child(ask)
	_fact = UI.label("", 15, UI.INK, 0)
	_fact.autowrap_mode = TextServer.AUTOWRAP_WORD
	_fact.custom_minimum_size = Vector2(440, 44)
	words.add_child(_fact)
	_back = UI.button("BACK", func() -> void: closed.emit())
	_back.custom_minimum_size = Vector2(120, 50)
	_back.add_theme_stylebox_override("normal", UI.card(Color(0.88, 0.83, 0.71), UI.INK, 2, 8))
	col.add_child(_back)
	show_page(0)


## The little world the models stand in: one light, a soft sky of paper blue, and a camera.
func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.86, 0.95)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, -0.7, 0.0)
	sun.light_energy = 1.25
	_view.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 36.0
	_view.add_child(_camera)
	_pivot = Node3D.new()
	_view.add_child(_pivot)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/psx.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for entry: Dictionary in PAGES:
		var node := Node3D.new()
		node.visible = false
		_pivot.add_child(node)
		_models.append(node)
		match str(entry.model):
			"nettle":
				_part(node, Props.sea_nettle(rng), mat, Vector3(0.0, 1.1, 0.0))
			"jelly":
				_part(node, Props.jelly(rng), mat, Vector3(0.0, 0.4, 0.0))
			"shark":
				_part(node, Props.shark_whole(), mat, Vector3.ZERO)
			"bear":
				_part(node, Props.bear_body(rng), mat, Vector3(0.0, -1.4, 0.0))
				var arm := Props.bear_arm(rng)
				for sx: float in [-1.0, 1.0]:
					_part(node, arm, mat, Vector3(sx * 0.9, 2.05 - 1.4, -0.1))
			_:
				# a salmon, side on to begin with
				_part(node, Props.salmon(str(entry.model)), mat, Vector3.ZERO)


func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func show_page(to: int) -> void:
	page = posmod(to, PAGES.size())
	var entry: Dictionary = PAGES[page]
	_kicker.text = entry.kicker
	_length.text = entry.length
	_name.text = entry.name
	_latin.text = entry.latin
	_fact.text = entry.fact
	for i in _models.size():
		_models[i].visible = i == page
	# side on to begin with
	_spin = PI * 0.5
	var reach: float = entry.reach
	_camera.position = Vector3(0.0, reach * 0.22, reach * 2.05)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func step(dir: int) -> void:
	show_page(page + dir)


func focus() -> void:
	_back.grab_focus()


# A finger (or the mouse) on the plate turns the model.
func _on_plate_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_held = event.pressed
	elif event is InputEventScreenTouch:
		_held = event.pressed
	elif event is InputEventMouseMotion and _held:
		_spin += event.relative.x * 0.012
	elif event is InputEventScreenDrag:
		_spin += event.relative.x * 0.012


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_left"):
		step(-1)
	elif event.is_action_pressed("ui_right"):
		step(1)
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _held:
		_spin += delta * 0.6
	_pivot.rotation.y = _spin
	# the card fills a phone held upright, and sits in the middle of a wide screen
	var area := size
	var card := _card.get_combined_minimum_size()
	_card.size = card
	var k := clampf(minf((area.x - 60.0) / card.x, (area.y - 60.0) / card.y), 0.5, 2.6)
	_wrap.scale = Vector2(k, k)
	_wrap.position = (area - card * k) * 0.5


func _diamond(at: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
