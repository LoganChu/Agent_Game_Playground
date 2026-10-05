class_name Glint
extends MeshInstance3D
## The faint twinkle over an inspectable (assets/shaders/glint.gdshader), so things worth
## examining can be spotted before the prompt appears. Shows within SHOW_FROM m of the player
## (fading in over FADE_SPAN m) and gives way to the "[E] Examine…" prompt inside `reach`.

const SHADER := preload("res://assets/shaders/glint.gdshader")
const SIZE := 0.6
const SHOW_FROM := 11.0
const FADE_SPAN := 4.0
## Default offset above the object's spot when its data has no `glint`.
const DEFAULT_OFFSET := Vector3(0, 1.1, 0)

var reach := 1.8
var _material: ShaderMaterial


func _init() -> void:
	name = "Glint"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("glint_color", PropFactory.color("kindle"))
	material_override = _material
	set_strength(0.0)


## How bright the glint is with the player `distance` m away (horizontal): nothing far off,
## full in the middle distance, gone again within reach (the prompt takes over).
static func strength_at(distance: float, p_reach: float) -> float:
	var far := 1.0 - smoothstep(SHOW_FROM - FADE_SPAN, SHOW_FROM, distance)
	var near := smoothstep(p_reach, p_reach + 1.0, distance)
	return far * near


func set_strength(value: float) -> void:
	_material.set_shader_parameter("strength", value)
	visible = value > 0.001


func strength() -> float:
	return float(_material.get_shader_parameter("strength"))


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP) as Node3D
	if player == null:
		set_strength(0.0)
		return
	var offset: Vector3 = player.global_position - global_position
	set_strength(strength_at(Vector2(offset.x, offset.z).length(), reach))
