class_name Atmosphere
extends Node
## The world's look: environment (sky, fog, ambient, glow, SSAO, grading) and the sun,
## driven by the region's mood (RegionMood.fog + RegionMood.light). Story changes tween
## the whole mood over MOOD_SECONDS, so a relit beacon visibly warms the light; the Greying
## under the player thickens the fog and drains the colour on top (set_greying).

const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")
const MOOD_SECONDS := 4.0
## Extra environment fog density and lost saturation at full Greying depth.
const GREYING_FOG_DENSITY := 0.05
const GREYING_DESATURATE := 0.45
## A little extra contrast and saturation so the flat palette doesn't read washed out.
const BASE_CONTRAST := 1.08
const BASE_SATURATION := 1.12

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial

## The mood currently shown (see _resolve); tweens blend between two of these.
var _shown: Dictionary = {}
var _from: Dictionary = {}
var _to: Dictionary = {}
var _tween: Tween
var _greying_look := 0.0


func _ready() -> void:
	environment = Environment.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.35
	# Glow picks out only what's emissive and bright (ember, beacon glass, lantern glass).
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Forward+ only (ignored by the Compatibility renderer): grounds props and characters.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.adjustment_enabled = true
	environment.adjustment_contrast = BASE_CONTRAST
	environment.adjustment_saturation = BASE_SATURATION
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	var start := _resolve(RegionMood.fog({}, WorldState.new()), RegionMood.light({}, WorldState.new()))
	_show(start)


## Shows a region's resolved fog + light: instantly, or tweened when the story changed it.
func apply_mood(fog: Dictionary, light: Dictionary, animate: bool) -> void:
	var target := _resolve(fog, light)
	if _tween:
		_tween.kill()
	if not animate:
		_show(target)
		return
	_from = _shown.duplicate()
	_to = target
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_blend, 0.0, 1.0, MOOD_SECONDS)


## The mood being shown or tweened towards (for tests): same keys as _resolve.
func target_mood() -> Dictionary:
	return _to if _tween and _tween.is_running() else _shown


## Smoothly follows the Greying depth under the player (0..1).
func follow_greying(depth: float, delta: float) -> void:
	_greying_look = move_toward(_greying_look, depth, delta * 0.8)
	_apply_greying()


func _resolve(fog: Dictionary, light: Dictionary) -> Dictionary:
	return {
		"fog_density": float(fog["density"]),
		"fog_color": PropFactory.color(str(fog["color"])),
		"sun_color": PropFactory.color(str(light["sun_color"])),
		"sun_energy": float(light["sun_energy"]),
		"sun_rotation": Vector3(float(light["sun_pitch"]), float(light["sun_yaw"]), 0.0),
		"ambient_color": PropFactory.color(str(light["ambient_color"])),
		"ambient_energy": float(light["ambient_energy"]),
		"sky_top": PropFactory.color(str(light["sky_top"])),
		"sky_horizon": PropFactory.color(str(light["sky_horizon"])),
	}


func _blend(t: float) -> void:
	var mood := {}
	for key: String in _to:
		mood[key] = lerp(_from[key], _to[key], t)
	_show(mood)


func _show(mood: Dictionary) -> void:
	_shown = mood
	environment.fog_light_color = mood["fog_color"]
	environment.ambient_light_color = mood["ambient_color"]
	environment.ambient_light_energy = mood["ambient_energy"]
	sun.light_color = mood["sun_color"]
	sun.light_energy = mood["sun_energy"]
	sun.rotation_degrees = mood["sun_rotation"]
	sky_material.set_shader_parameter("sky_top", mood["sky_top"])
	sky_material.set_shader_parameter("sky_horizon", mood["sky_horizon"])
	sky_material.set_shader_parameter("sun_color", mood["sun_color"])
	# Thicker fog, heavier cloud banks.
	sky_material.set_shader_parameter("cloud_amount", clampf(float(mood["fog_density"]) * 25.0, 0.2, 1.0))
	_apply_greying()


func _apply_greying() -> void:
	if _shown.is_empty():
		return
	environment.fog_density = float(_shown["fog_density"]) + _greying_look * GREYING_FOG_DENSITY
	environment.adjustment_saturation = BASE_SATURATION * (1.0 - _greying_look * GREYING_DESATURATE)
