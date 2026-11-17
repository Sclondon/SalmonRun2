class_name SalmonModel
## The salmon as it is drawn: GameCommon's sockeye (creatures/sockeye_salmon: a model built in
## Blender for each stage of its life, with one shader that swims it and draws its markings), in
## place of the fish that Props.salmon builds in code. (The user, 2026-11-17: "We need to update
## salmon run with this new model, and make new models for all the other life stages in salmon run
## just as good".)
##
## The game still thinks of its salmon as it always has: a mesh on a MeshInstance3D with a
## ShaderMaterial of its own, about 2.6 long with its nose at -Z, posed with the fish shader's
## `wag_phase`, `wag_amp`, `curl` (up and down), `bend` (to one side) and `flash`. This is the
## go-between: `mesh` and `dress` give a node its model and its material for a stage, `SCALE` is
## how much bigger than the model (0.6 m) the game's fish is, and `pose` turns the game's
## settings into the model's.
##
## Props.salmon and SALMON_LOOKS are kept (the sizes still come from there, and the old fish can
## be looked at beside the new).

## How many times bigger than the model the game's salmon is: the code-built fish was 2.62 long.
const SCALE := 2.62 / SockeyeSalmon.LENGTH

## The game's name for each stage of its life, and the model's.
const STAGES := {
	"fry": SockeyeSalmon.Stage.FRY,
	"parr": SockeyeSalmon.Stage.PARR,
	"smolt": SockeyeSalmon.Stage.SMOLT,
	"ocean": SockeyeSalmon.Stage.OCEAN,
	"migrating": SockeyeSalmon.Stage.MIGRATING,
	"spawner": SockeyeSalmon.Stage.SPAWNER,
	"female": SockeyeSalmon.Stage.SPAWNER_FEMALE,
}


## The model for a stage ("fry" ... "spawner", or "female": the spawning female). `low`: the
## model with a twelfth of the triangles, for the packs.
static func mesh(look: String, low := false) -> Mesh:
	return SockeyeSalmon.mesh_of(STAGES[look], low)


## Makes `mat` the salmon's material for a stage (a mesh must be drawn with the material of its
## own stage: it carries where that stage's jaw hinges and its head ends). `plain`: without the
## skin's fine detail (blotches, scales, streaks), which is the dear part of it: for the packs.
static func dress(mat: ShaderMaterial, look: String, plain := false) -> void:
	mat.shader = SockeyeSalmon.SHADER
	# (whatever an earlier stage set that this one does not is put back as the shader has it)
	for stage: int in SockeyeSalmon.STAGES:
		for setting: String in SockeyeSalmon.STAGES[stage]:
			mat.set_shader_parameter(setting, null)
	for setting: String in SockeyeSalmon.PLAIN:
		mat.set_shader_parameter(setting, null)
	SockeyeSalmon._wear(mat, STAGES[look])
	if plain:
		for setting: String in SockeyeSalmon.PLAIN:
			mat.set_shader_parameter(setting, SockeyeSalmon.PLAIN[setting])
	# (four beats of the tail to one of everything else: a breath, two sculls of the fins)
	mat.set_shader_parameter("tail_beats", 4.0)
	mat.set_shader_parameter("breaths", 1.0)
	mat.set_shader_parameter("sculls", 2.0)
	# (the rim of light the game's fish have, so that it stands out from the water)
	mat.set_shader_parameter("rim", 1.0)
	pose(mat, 0.0, 0.12)


## A new material for a stage (see `dress`).
static func material(look: String, plain := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	dress(mat, look, plain)
	return mat


## Poses a salmon as the game's fish shader would from the same settings: `wag_phase` (radians,
## running on), `wag_amp` (0.12 as it cruises), `curl` (up and down: more than 0 lifts its head
## and tail), `bend` (to one side), `flash` (white).
static func pose(mat: ShaderMaterial, wag_phase: float, wag_amp: float, curl := 0.0, bend := 0.0, flash := 0.0) -> void:
	mat.set_shader_parameter("phase", fposmod(wag_phase / (TAU * 4.0), 1.0))
	mat.set_shader_parameter("swim", wag_amp * 6.0)
	mat.set_shader_parameter("arch", curl * 2.0)
	mat.set_shader_parameter("curl", bend * 1.6)
	mat.set_shader_parameter("flash", flash)
	# (the PS1 wobble, an option: see main.gd)
	mat.set_shader_parameter("snap", Save.wobble)
