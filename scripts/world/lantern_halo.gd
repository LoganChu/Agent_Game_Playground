class_name LanternHalo
extends MeshInstance3D
## A soft glow round a lantern's glass (assets/shaders/lantern_halo.gdshader), so a lantern
## reads from across a clearing or up on a ridge without spending a real light (the light
## budget: ember, ferry lantern, beacon). Region data: a model prop's `halo` = [x, y, z] in
## model space (the glass centre), `halo_size` = the quad's width in metres.

const SHADER := preload("res://assets/shaders/lantern_halo.gdshader")
const SIZE := 1.8


static func build(at: Vector3, size: float = SIZE) -> LanternHalo:
	var halo := LanternHalo.new()
	halo.name = "LanternHalo"
	halo.position = at
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	halo.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("halo_color", PropFactory.color("kindle"))
	halo.material_override = material
	return halo
