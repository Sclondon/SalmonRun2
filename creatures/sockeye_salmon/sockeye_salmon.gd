class_name SockeyeSalmon
extends Node3D
## A sockeye salmon (Oncorhynchus nerka) at any stage of its life (`stage`), each stage a
## model of its own, all built 0.6 m long (`SIZE` is how long each really is beside the
## adult):
##
## - FRY: just past the yolk sac: a big head and very big eyes, a slim body, small pale
##   fins; pale olive-gold with faint parr marks.
## - PARR: the young fish of streams and lakes: olive back with small dark spots, silvery
##   sides with a row of short dark oval parr marks, a deeply forked tail.
## - SMOLT: on its way to sea: slim, bright silver, blue-green back, the parr marks all
##   but gone, a dark-edged tail.
## - OCEAN: the full-grown fish at sea: streamlined, steel blue-green back, silver sides.
## - MIGRATING: on its way upriver: the body blushing red, the head going green, a slight
##   hump and the start of a hook to the snout.
## - SPAWNER (the default): the spawning male: bright red, a humped back, an olive-green
##   head whose black snout turns down in a hook (the kype), a white lower jaw.
## - SPAWNER_FEMALE: the spawning female: the same red body and green head, but no hump
##   and no hook: a smooth, fuller body deep in the belly, a short blunt snout.
##
## Each has a lower jaw that works, the upper lip plate (maxilla), gill covers, eyes, a
## dorsal fin, the small adipose fin, a forked tail, an anal fin and a pair each of pelvic
## and pectoral fins. No spots on the grown fish: a sockeye has none. All of its markings
## are drawn by its shader: no texture files. `set_shader_parameter` reaches every colour.
## Its nose points along its own -Z, its belly down; its origin is the middle of its length.
##
## It swims by a wave down its body, drawn by the shader (no bones): the head nearly
## still, the tail swinging widest, its fins and tail carried and turned with the
## bend; its mouth and gill covers work as it breathes; its pectoral fins scull.
##
## Everything that moves runs on `phase`, 0 to 1 through one `beat`: in a beat the
## tail beats `tail_beats` times, it breathes `breaths` times and its fins scull
## `sculls` times (whole numbers), so its motion comes round again exactly every
## beat. Either call `step(velocity, delta)` each frame, which moves `phase` on by
## delta / beat (and swims harder the faster it is going), or set `phase` yourself
## (for a picture that must loop: frame / frames in a beat; with `beat` 0, `step`
## leaves `phase` alone, for a caller that sets it).
##
## A game that keeps its own MeshInstance3Ds needs no SockeyeSalmon node:
## `SockeyeSalmon.mesh_of(stage, low)` is a stage's mesh and
## `SockeyeSalmon.new_material(stage)` a material for it, whose shader settings (phase,
## swim, tail_beats, curl, arch, flash, rim, snap and the rest) the game sets itself.
##
## How it looks and moves only: whatever moves it puts it where it is and turns it
## the way it goes. `scale` it for a bigger or smaller one. No sound.
##
## The models are creatures/sockeye_salmon/models/sockeye_<stage>.glb (and _lo), built
## by tools/build_sockeye_salmon.py; its shader is sockeye_salmon.gdshader.

enum Stage { FRY, PARR, SMOLT, OCEAN, MIGRATING, SPAWNER, SPAWNER_FEMALE }

const MODEL := "res://creatures/sockeye_salmon/models/sockeye_%s%s.glb"
const SHADER := preload("res://creatures/sockeye_salmon/sockeye_salmon.gdshader")
## As the models are built (tools/build_sockeye_salmon.py): snout to tail tip, every stage
## (metres, at scale 1).
const LENGTH := 0.6
## Each stage's name in its model's file name.
const NAMES := {
	Stage.FRY: "fry", Stage.PARR: "parr", Stage.SMOLT: "smolt", Stage.OCEAN: "ocean",
	Stage.MIGRATING: "migrating", Stage.SPAWNER: "spawner", Stage.SPAWNER_FEMALE: "spawner_female",
}
## How long each stage really is beside a full-grown male (1): a fry about 3 cm, a parr
## 7 cm, a smolt 10 cm, the grown fish 60 cm. Multiply a stage's `scale` by this for
## fish in their true sizes; a game may well want its young bigger than life.
const SIZE := {
	Stage.FRY: 0.05, Stage.PARR: 0.12, Stage.SMOLT: 0.17, Stage.OCEAN: 1.0,
	Stage.MIGRATING: 1.0, Stage.SPAWNER: 1.0, Stage.SPAWNER_FEMALE: 0.93,
}
## What each stage sets in the shader: where its jaw hinges and its gill cover ends (as
## its model is built: the build script prints them), its colours as they are seen, and
## how strong its markings are.
const STAGES := {
	Stage.FRY: {
		"hinge_s": 0.126, "hinge_y": -0.0342, "gill_s": 0.246,
		"back": Color(0.4, 0.38, 0.2), "side": Color(0.8, 0.76, 0.56), "low": Color(0.88, 0.86, 0.72),
		"belly": Color(0.95, 0.93, 0.84), "head": Color(0.68, 0.63, 0.44), "head_top": Color(0.38, 0.36, 0.2),
		"snout": Color(0.4, 0.37, 0.24), "jaw_pale": Color(0.93, 0.9, 0.78), "parr": Color(0.2, 0.22, 0.16),
		"fin_dorsal": Color(0.82, 0.78, 0.6), "fin_adipose": Color(0.78, 0.72, 0.52), "fin_tail": Color(0.86, 0.76, 0.52),
		"fin_anal": Color(0.88, 0.85, 0.7), "fin_pelvic": Color(0.88, 0.85, 0.7),
		"fin_pectoral": Color(0.86, 0.83, 0.68), "fin_dark": Color(0.5, 0.46, 0.32),
		"sheen_colour": Color(1.0, 0.95, 0.8), "back_from": 0.6, "belly_fade": 0.0, "mottle": 0.4,
		"scales": 0.0, "parr_amount": 0.45, "spot_amount": 0.0, "tail_streaks": 0.0, "tail_edge": 0.0,
		"fin_dusk": 0.3, "sheen": 0.3,
	},
	Stage.PARR: {
		"hinge_s": 0.1186, "hinge_y": -0.0324, "gill_s": 0.2316,
		"back": Color(0.22, 0.28, 0.13), "side": Color(0.74, 0.74, 0.56), "low": Color(0.86, 0.87, 0.78),
		"belly": Color(0.96, 0.96, 0.9), "head": Color(0.6, 0.62, 0.46), "head_top": Color(0.22, 0.27, 0.13),
		"snout": Color(0.2, 0.23, 0.13), "jaw_pale": Color(0.93, 0.92, 0.84), "parr": Color(0.12, 0.17, 0.14),
		"fin_dorsal": Color(0.62, 0.6, 0.38), "fin_adipose": Color(0.56, 0.52, 0.3), "fin_tail": Color(0.66, 0.62, 0.38),
		"fin_anal": Color(0.84, 0.8, 0.6), "fin_pelvic": Color(0.86, 0.82, 0.62),
		"fin_pectoral": Color(0.8, 0.76, 0.56), "fin_dark": Color(0.3, 0.3, 0.2),
		"sheen_colour": Color(0.95, 1.0, 0.9), "back_from": 0.56, "belly_fade": 0.0, "mottle": 0.5,
		"scales": 0.5, "parr_amount": 0.85, "spot_amount": 0.8, "tail_streaks": 0.0, "tail_edge": 0.3,
		"fin_dusk": 0.4, "sheen": 0.4,
	},
	Stage.SMOLT: {
		"hinge_s": 0.1092, "hinge_y": -0.03, "gill_s": 0.2132,
		"back": Color(0.09, 0.28, 0.34), "side": Color(0.74, 0.8, 0.82), "low": Color(0.87, 0.9, 0.91),
		"belly": Color(0.97, 0.98, 0.98), "head": Color(0.68, 0.76, 0.77), "head_top": Color(0.1, 0.27, 0.32),
		"snout": Color(0.13, 0.24, 0.28), "jaw_pale": Color(0.94, 0.95, 0.94), "parr": Color(0.3, 0.42, 0.46),
		"fin_dorsal": Color(0.6, 0.68, 0.66), "fin_adipose": Color(0.56, 0.64, 0.58), "fin_tail": Color(0.62, 0.7, 0.7),
		"fin_anal": Color(0.88, 0.9, 0.88), "fin_pelvic": Color(0.88, 0.9, 0.88),
		"fin_pectoral": Color(0.76, 0.8, 0.8), "fin_dark": Color(0.1, 0.14, 0.17),
		"sheen_colour": Color(0.88, 0.96, 1.0), "back_from": 0.52, "belly_fade": 0.0, "mottle": 0.25,
		"scales": 1.2, "parr_amount": 0.12, "spot_amount": 0.0, "tail_streaks": 0.0, "tail_edge": 1.0,
		"fin_dusk": 0.5, "sheen": 0.7,
	},
	Stage.OCEAN: {
		"hinge_s": 0.105, "hinge_y": -0.03, "gill_s": 0.205,
		"back": Color(0.07, 0.22, 0.3), "side": Color(0.66, 0.72, 0.74), "low": Color(0.82, 0.85, 0.86),
		"belly": Color(0.96, 0.96, 0.95), "head": Color(0.62, 0.69, 0.68), "head_top": Color(0.08, 0.22, 0.28),
		"snout": Color(0.1, 0.18, 0.22), "jaw_pale": Color(0.93, 0.94, 0.92), "parr": Color(0.18, 0.24, 0.22),
		"fin_dorsal": Color(0.5, 0.58, 0.52), "fin_adipose": Color(0.56, 0.62, 0.5), "fin_tail": Color(0.4, 0.48, 0.48),
		"fin_anal": Color(0.84, 0.86, 0.8), "fin_pelvic": Color(0.84, 0.86, 0.82),
		"fin_pectoral": Color(0.6, 0.66, 0.64), "fin_dark": Color(0.12, 0.17, 0.2),
		"sheen_colour": Color(0.85, 0.95, 1.0), "back_from": 0.5, "belly_fade": 0.0, "mottle": 0.3,
		"scales": 1.3, "parr_amount": 0.0, "spot_amount": 0.0, "tail_streaks": 0.2, "tail_edge": 0.5,
		"fin_dusk": 1.0, "sheen": 0.6,
	},
	Stage.MIGRATING: {
		"hinge_s": 0.1185, "hinge_y": -0.0318, "gill_s": 0.2189,
		"back": Color(0.3, 0.13, 0.14), "side": Color(0.74, 0.34, 0.31), "low": Color(0.84, 0.56, 0.52),
		"belly": Color(0.93, 0.89, 0.86), "head": Color(0.44, 0.52, 0.36), "head_top": Color(0.13, 0.23, 0.17),
		"snout": Color(0.08, 0.12, 0.1), "jaw_pale": Color(0.92, 0.92, 0.87), "parr": Color(0.18, 0.24, 0.22),
		"fin_dorsal": Color(0.56, 0.36, 0.28), "fin_adipose": Color(0.64, 0.3, 0.24), "fin_tail": Color(0.4, 0.44, 0.32),
		"fin_anal": Color(0.72, 0.42, 0.36), "fin_pelvic": Color(0.7, 0.44, 0.38),
		"fin_pectoral": Color(0.5, 0.52, 0.44), "fin_dark": Color(0.11, 0.13, 0.12),
		"sheen_colour": Color(0.95, 0.85, 0.85), "back_from": 0.56, "belly_fade": 0.5, "mottle": 0.8,
		"scales": 0.9, "parr_amount": 0.0, "spot_amount": 0.0, "tail_streaks": 0.45, "tail_edge": 0.5,
		"fin_dusk": 1.0, "sheen": 0.4,
	},
	Stage.SPAWNER: {
		"hinge_s": 0.135, "hinge_y": -0.034, "gill_s": 0.236,
		"back": Color(0.5, 0.05, 0.04), "side": Color(0.78, 0.07, 0.05), "low": Color(0.86, 0.2, 0.17),
		"belly": Color(0.92, 0.86, 0.82), "head": Color(0.4, 0.42, 0.13), "head_top": Color(0.17, 0.21, 0.07),
		"snout": Color(0.07, 0.08, 0.05), "jaw_pale": Color(0.92, 0.9, 0.84), "parr": Color(0.18, 0.24, 0.22),
		"fin_dorsal": Color(0.74, 0.2, 0.1), "fin_adipose": Color(0.8, 0.12, 0.08), "fin_tail": Color(0.4, 0.4, 0.16),
		"fin_anal": Color(0.72, 0.16, 0.1), "fin_pelvic": Color(0.66, 0.17, 0.11),
		"fin_pectoral": Color(0.42, 0.4, 0.3), "fin_dark": Color(0.1, 0.1, 0.07),
		"sheen_colour": Color(1.0, 0.72, 0.62), "back_from": 0.62, "belly_fade": 1.0, "mottle": 1.0,
		"scales": 0.6, "parr_amount": 0.0, "spot_amount": 0.0, "tail_streaks": 0.75, "tail_edge": 0.5,
		"fin_dusk": 1.0, "sheen": 0.25,
	},
	Stage.SPAWNER_FEMALE: {
		"hinge_s": 0.108, "hinge_y": -0.0304, "gill_s": 0.2081,
		"back": Color(0.46, 0.07, 0.06), "side": Color(0.74, 0.1, 0.07), "low": Color(0.76, 0.3, 0.26),
		"belly": Color(0.84, 0.8, 0.78), "head": Color(0.38, 0.44, 0.2), "head_top": Color(0.15, 0.22, 0.1),
		"snout": Color(0.1, 0.13, 0.08), "jaw_pale": Color(0.9, 0.9, 0.85), "parr": Color(0.18, 0.24, 0.22),
		"fin_dorsal": Color(0.72, 0.24, 0.14), "fin_adipose": Color(0.76, 0.14, 0.1), "fin_tail": Color(0.44, 0.44, 0.22),
		"fin_anal": Color(0.7, 0.2, 0.14), "fin_pelvic": Color(0.64, 0.2, 0.14),
		"fin_pectoral": Color(0.4, 0.4, 0.32), "fin_dark": Color(0.1, 0.1, 0.08),
		"sheen_colour": Color(1.0, 0.75, 0.66), "back_from": 0.62, "belly_fade": 1.0, "mottle": 1.0,
		"scales": 0.7, "parr_amount": 0.0, "spot_amount": 0.0, "tail_streaks": 0.6, "tail_edge": 0.5,
		"fin_dusk": 1.0, "sheen": 0.25,
	},
}
## What a material for fish in a pack leaves out (see `new_material`).
const PLAIN := {"mottle": 0.0, "scales": 0.0, "spot_amount": 0.0, "tail_streaks": 0.0}

static var _meshes := {}

## Which stage of its life it is at: its shape and its colours.
@export var stage := Stage.SPAWNER:
	set(value):
		stage = value
		_dress()
		_fit()
## Seconds one beat takes: everything it does comes round again each beat. 0 for a
## caller that sets `phase` itself (`step` then leaves `phase` alone).
@export var beat := 2.4
## How many times in a beat its tail beats, it breathes, and its pectoral fins scull.
@export var tail_beats := 3:
	set(value):
		tail_beats = maxi(value, 0)
		_send(&"tail_beats", float(tail_beats))
@export var breaths := 2:
	set(value):
		breaths = maxi(value, 0)
		_send(&"breaths", float(breaths))
@export var sculls := 2:
	set(value):
		sculls = maxi(value, 0)
		_send(&"sculls", float(sculls))
## How hard it swims when it is not going anywhere (holding its place in a current):
## 0 hangs still, 1 swings its tail a tenth of its length each way.
@export_range(0.0, 1.0) var swim := 0.5:
	set(value):
		swim = value
		_effort = value
		_send(&"swim", _effort)
## The speed (m/s, at scale 1) at which `step` has it swimming as hard as it can.
@export var top_speed := 1.8
## The low model (far off, phones) in place of the full one.
@export var low := false:
	set(value):
		low = value
		_show()
## How far through a beat it is, 0 to 1. `step` moves it on; or set it yourself.
var phase := 0.0:
	set(value):
		phase = fposmod(value, 1.0)
		_send(&"phase", phase)

var _material: ShaderMaterial
var _full: MeshInstance3D
var _low: MeshInstance3D
var _effort := 0.5


## A stage's mesh (the low one for fish far off, in packs, on phones), for a game that
## keeps its own MeshInstance3Ds. Each is loaded once and kept.
static func mesh_of(stage_wanted: Stage, low_wanted := false) -> Mesh:
	var path := MODEL % [NAMES[stage_wanted], "_lo" if low_wanted else ""]
	if not _meshes.has(path):
		var made := (load(path) as PackedScene).instantiate()
		var found: MeshInstance3D = made.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[path] = found.mesh
		made.free()
	return _meshes[path]


## A new material for a stage's mesh, dressed in that stage's colours and markings. Its
## shader settings are the game's to set: phase (0..1), swim, tail_beats, breaths, sculls,
## curl, arch, flash, rim, snap and the rest (the top of the shader lists them). `plain`
## leaves out what costs most to draw and shows least far off (the skin's blotches, the
## scales, the back's spots, the tail's streaks): for packs of fish on phones.
static func new_material(stage_wanted: Stage, plain := false) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = SHADER
	_wear(made, stage_wanted)
	if plain:
		for setting: String in PLAIN:
			made.set_shader_parameter(setting, PLAIN[setting])
	return made


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_effort = swim
	_dress()


func _ready() -> void:
	_full = _instance_of("Salmon")
	_low = _instance_of("Salmon_lo")
	_fit()
	_show()
	for setting: StringName in [&"tail_beats", &"breaths", &"sculls"]:
		_send(setting, float(get(setting)))
	_send(&"swim", _effort)
	_send(&"phase", phase)


## Each frame, after putting it where it is: moves its beat on by `delta` seconds
## (unless `beat` is 0), and has it swim harder the faster it is going (`velocity`,
## world, m/s; give Vector3.ZERO for one that holds its place, and it swims as
## `swim` says).
func step(velocity: Vector3, delta: float) -> void:
	if beat > 0.0:
		phase += delta / beat
	var size := maxf(global_basis.get_scale().z, 0.001) if is_inside_tree() else 1.0
	var wanted := maxf(swim, clampf(velocity.length() / (top_speed * size), 0.0, 1.0))
	_effort = move_toward(_effort, wanted, delta * 1.5)
	_send(&"swim", _effort)


## Sets one of the shader's settings: a colour (back, side, low, belly, head, head_top,
## snout, jaw_pale, mouth, parr, fin_dorsal, fin_adipose, fin_tail, fin_anal, fin_pelvic,
## fin_pectoral, fin_dark, eye_gold, sheen_colour), an amount (back_from, belly_fade,
## mottle, scales, parr_amount, spot_amount, tail_streaks, tail_edge, fin_dusk, sheen),
## how it moves (curl, arch, gape, gape_breath, gill_flare, scull), or a game's effects
## (flash, rim, snap, snap_res). `stage` sets most of the colours and amounts again.
func set_shader_parameter(setting: StringName, value: Variant) -> void:
	_send(setting, value)


## The material it is drawn with.
func material() -> ShaderMaterial:
	return _material


func _send(setting: StringName, value: Variant) -> void:
	if _material:
		_material.set_shader_parameter(setting, value)


static func _wear(on: ShaderMaterial, stage_wanted: Stage) -> void:
	var wears: Dictionary = STAGES[stage_wanted]
	for setting: String in wears:
		on.set_shader_parameter(setting, wears[setting])


func _dress() -> void:
	if _material:
		_wear(_material, stage)


func _fit() -> void:
	if _full:
		_full.mesh = mesh_of(stage, false)
		_low.mesh = mesh_of(stage, true)


func _show() -> void:
	if _full:
		_full.visible = not low
		_low.visible = low


func _instance_of(called: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.material_override = _material
	# (its tail swings out past the still model's box)
	mesh.extra_cull_margin = LENGTH * 0.25
	mesh.name = called
	add_child(mesh)
	return mesh
