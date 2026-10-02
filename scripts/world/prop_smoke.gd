class_name PropSmoke
extends RefCounted
## Smoke rising from a model prop (a region prop's `smoke` field): a stove pipe, a charcoal
## clamp's vents. `"smoke": [[x, y, z], ...]` lists the vents in model space (before the
## prop's `scale`); each gets a slow column of low-poly puffs that swell, lean downwind and
## fade. Particles are CPU-side so the Compatibility renderer shows them too, and they are
## preprocessed so the column is already standing when the region loads.

const AMOUNT := 16
const LIFETIME := 6.0
## World-space drift of the puffs (a light breeze off the sea, rising).
const DRIFT := Vector3(0.12, 0.1, 0.05)


## One CPUParticles3D per vent, as children of a "Smoke" node to add under the prop's model.
static func build(vents: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Smoke"
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.36
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 1.0
	mesh.material = material
	var scale_curve := Curve.new()
	scale_curve.max_value = 3.0
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(1.0, 2.6))
	var ramp := Gradient.new()
	var tint := PropFactory.color("silverfog").lerp(PropFactory.color("bone"), 0.4)
	ramp.set_color(0, Color(tint.darkened(0.2), 0.0))
	ramp.add_point(0.12, Color(tint.darkened(0.1), 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint, 0.0))
	for i in vents.size():
		var particles := CPUParticles3D.new()
		particles.name = "Vent%d" % i
		particles.position = JsonUtil.to_vector3(vents[i])
		particles.mesh = mesh
		particles.amount = AMOUNT
		particles.lifetime = LIFETIME
		particles.preprocess = LIFETIME
		particles.randomness = 0.5
		particles.local_coords = false
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 0.06
		particles.direction = Vector3.UP
		particles.spread = 12.0
		particles.gravity = DRIFT
		particles.initial_velocity_min = 0.4
		particles.initial_velocity_max = 0.6
		particles.angle_min = 0.0
		particles.angle_max = 180.0
		particles.scale_amount_curve = scale_curve
		particles.color_ramp = ramp
		root.add_child(particles)
	return root
