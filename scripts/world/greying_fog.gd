class_name GreyingFog
extends MeshInstance3D
## The visible fog of one Greying area: a few translucent layers hugging the ground (or the
## water), each vertex's alpha baked from `Greying.area_depth` (thinned by any clear areas of
## light over it), animated by
## assets/shaders/greying_fog.gdshader. Built by Region; fades in/out when the story adds
## or removes the area.

const SHADER := preload("res://assets/shaders/greying_fog.gdshader")
const LAYERS := 5
## Alpha of the lowest layer at full depth; higher layers get thinner.
const BASE_ALPHA := 0.42
const FADE_SECONDS := 4.0
## Grid spacing of the layer meshes (metres).
const STEP := 1.0

var area: Dictionary = {}
var _material: ShaderMaterial


var _surface: Callable
var _recut_tween: Tween


## Builds the layers for `area`. `surface` maps x, z → the height the fog lies on; `clears`
## are the clear areas (lantern light) currently cutting pools out of it.
func setup(p_area: Dictionary, surface: Callable, clears: Array[Dictionary] = [], color_name: String = "silverfog") -> void:
	area = p_area
	_surface = surface
	name = "GreyingFog"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = build_mesh(area, surface, clears)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fog_color", PropFactory.color(color_name))
	material_override = _material


## Tweens the fog in from nothing (areas the story just added) or out and frees it.
func fade(to_visible: bool) -> void:
	_material.set_shader_parameter("opacity", 0.0 if to_visible else 1.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_opacity, 0.0 if to_visible else 1.0, 1.0 if to_visible else 0.0, FADE_SECONDS)
	if not to_visible:
		tween.tween_callback(queue_free)


func _set_opacity(value: float) -> void:
	_material.set_shader_parameter("opacity", value)


## Re-cuts the layers when the light over them changes (a lantern lit or put out). With
## `animate`, the old cut dissolves into the new one over FADE_SECONDS: the mesh carries both
## alphas (UV2.y new, UV2.x old) and the shader blends them by `recut`.
func recut(clears: Array[Dictionary], from_clears: Array[Dictionary], animate: bool = true) -> void:
	if _recut_tween:
		_recut_tween.kill()
		_recut_tween = null
	if not animate:
		mesh = build_mesh(area, _surface, clears)
		_material.set_shader_parameter("recut", 1.0)
		return
	mesh = build_mesh(area, _surface, clears, from_clears)
	_material.set_shader_parameter("recut", 0.0)
	_recut_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_recut_tween.tween_method(_set_recut, 0.0, 1.0, FADE_SECONDS)
	# Drop the old cut's triangles once it has faded.
	_recut_tween.tween_callback(func() -> void: mesh = build_mesh(area, _surface, clears))


func _set_recut(value: float) -> void:
	_material.set_shader_parameter("recut", value)


## How far the current re-cut has faded in (1 = settled; for tests).
func recut_progress() -> float:
	return float(_material.get_shader_parameter("recut")) if _material else 1.0


## The layer mesh: LAYERS stacked grids over the area's bounds; triangles that are clear of
## fog at all three corners are dropped. Each vertex's alpha under `clears` is in COLOR.a
## and (full precision, for the shader) UV2.y; UV2.x is its alpha under `from_clears` (the cut
## being faded out — see `recut`), or the same alpha when there is none. A triangle stays while either cut leaves fog on it.
static func build_mesh(p_area: Dictionary, surface: Callable, clears: Array[Dictionary] = [], from_clears: Variant = null) -> ArrayMesh:
	var bounds := Greying.area_bounds(p_area)
	var nx := maxi(1, ceili(bounds.size.x / STEP))
	var nz := maxi(1, ceili(bounds.size.y / STEP))
	var height := float(p_area.get("height", Greying.DEFAULT_HEIGHT))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depths := PackedFloat32Array()
	var olds := PackedFloat32Array()
	var grounds := PackedFloat32Array()
	for iz in nz + 1:
		for ix in nx + 1:
			var p := bounds.position + Vector2(ix * bounds.size.x / nx, iz * bounds.size.y / nz)
			var raw := Greying.area_depth(p_area, p)
			depths.append(raw * (1.0 - Greying.clearing_at(clears, p)))
			if from_clears is Array:
				var old_clears: Array[Dictionary] = []
				old_clears.assign(from_clears)
				olds.append(raw * (1.0 - Greying.clearing_at(old_clears, p)))
			else:
				olds.append(depths[depths.size() - 1])
			grounds.append(float(surface.call(p.x, p.y)))
	var any := false
	for layer in LAYERS:
		var t := (layer + 0.5) / LAYERS
		var y_off := height * t
		var weight := BASE_ALPHA * pow(1.0 - t * 0.85, 1.5)
		for iz in nz:
			for ix in nx:
				var ids := [iz * (nx + 1) + ix, iz * (nx + 1) + ix + 1, (iz + 1) * (nx + 1) + ix, (iz + 1) * (nx + 1) + ix + 1]
				for tri: Array in [[ids[0], ids[1], ids[3]], [ids[0], ids[3], ids[2]]]:
					if depths[tri[0]] <= 0.0 and depths[tri[1]] <= 0.0 and depths[tri[2]] <= 0.0 \
							and olds[tri[0]] <= 0.0 and olds[tri[1]] <= 0.0 and olds[tri[2]] <= 0.0:
						continue
					any = true
					for i: int in tri:
						var gx := i % (nx + 1)
						var gz := i / (nx + 1)
						var p := bounds.position + Vector2(gx * bounds.size.x / nx, gz * bounds.size.y / nz)
						st.set_color(Color(1, 1, 1, depths[i] * weight))
						st.set_uv2(Vector2(olds[i] * weight, depths[i] * weight))
						st.set_normal(Vector3.UP)
						st.add_vertex(Vector3(p.x, grounds[i] + y_off, p.y))
	if not any:
		return ArrayMesh.new()
	return st.commit()
