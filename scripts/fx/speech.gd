extends Node3D
## What the salmon has to say for itself: a speech bubble that pops up beside it in the world
## (not on the glass of the screen) with a word in it, how well a swipe was timed (SLOPPY,
## GOOD, PERFECT! and the rest), and is gone again in a moment.

const UI := preload("res://scripts/ui/ui_kit.gd")

## How tall the bubble is (metres), and where it stands from the one speaking.
const TALL := 1.15
const AT := Vector3(1.7, 1.7, 0.0)

var who: Node3D

var _card: MeshInstance3D
var _mat: ShaderMaterial
var _word: Label3D
var _left := 0.0
var _age := 0.0


func _ready() -> void:
	top_level = true
	visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/speech.gdshader")
	_mat.render_priority = 5
	_card = MeshInstance3D.new()
	_card.mesh = quad
	_card.material_override = _mat
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_card)
	_word = Label3D.new()
	_word.font = UI.font()
	_word.font_size = 64
	_word.outline_size = 0
	_word.pixel_size = 0.0095
	_word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_word.no_depth_test = true
	_word.render_priority = 6
	_word.shaded = false
	# (the word sits in the box, which is the upper part of the card)
	_word.offset = Vector2(0.0, 11.0)
	add_child(_word)


## Says `text`, in `colour`, for `seconds`.
func say(text: String, colour: Color, seconds := 0.9) -> void:
	_word.text = text
	# (dark enough to read on the pale bubble, whatever colour it is)
	# (the palest of them, PERFECT!, is written in gold instead)
	_word.modulate = Color(0.72, 0.5, 0.05) if colour.s < 0.15 else colour.darkened(0.5)
	var wide := maxf(text.length() * 0.42 + 0.7, 1.9)
	_card.scale = Vector3(wide * TALL, TALL, 1.0)
	_mat.set_shader_parameter("aspect", wide)
	_left = seconds
	_age = 0.0
	visible = true


func _process(delta: float) -> void:
	if not visible or who == null:
		return
	_left -= delta
	_age += delta
	if _left <= 0.0:
		visible = false
		return
	# (it pops up, a little too big, and settles; and shrinks away at the end)
	var pop := 1.0 + 0.35 * maxf(1.0 - _age / 0.12, 0.0)
	pop *= clampf(_left / 0.12, 0.0, 1.0)
	scale = Vector3.ONE * maxf(pop, 0.01)
	# beside the one speaking, up and to its right as the eye sees it
	var cam := get_viewport().get_camera_3d()
	var across := cam.global_transform.basis.x if cam else Vector3.RIGHT
	global_position = who.global_position + across * AT.x + Vector3.UP * AT.y
