class_name FloatingProp
extends Node3D
## A model prop riding the water (a region prop's `float` field): the model bobs and rolls on
## a slow swell while a foam ring where its hull meets the water stays level and breathes.
##   "float": {"bob": 0.05, "roll": 1.5, "period": 4.5, "foam": [rx, rz], "foam_y": 0.0}
## `bob` metres up/down, `roll` degrees side to side (half that fore and aft), `period`
## seconds per swell, `foam` the ring's inner radii across/along the hull (model space, before
## the prop's `scale`), `foam_y` the waterline's height above the model origin. Each prop
## starts at a phase taken from its position, so moored boats don't bob in step.

const KEYS: Array[String] = ["bob", "roll", "period", "foam", "foam_y", "note"]
## Width of the foam ring outside the hull (m) and how far it tucks in under the hull.
const FOAM_WIDTH := 0.55
const FOAM_TUCK := 0.85
const FOAM_SEGMENTS := 28

var bob := 0.05
var roll := 1.5
var period := 4.5
var phase := 0.0

var _model: Node3D
var _foam: MeshInstance3D
var _time := 0.0


## Wraps `model` (already scaled) in a FloatingProp built from a `float` spec. The caller
## positions and turns the returned node; the model and foam are its children.
static func wrap(model: Node3D, spec: Dictionary, scale_factor: float = 1.0) -> FloatingProp:
	var prop := FloatingProp.new()
	prop.name = "Floating_" + model.name
	prop.bob = float(spec.get("bob", 0.05))
	prop.roll = float(spec.get("roll", 1.5))
	prop.period = maxf(0.5, float(spec.get("period", 4.5)))
	prop._model = model
	prop.add_child(model)
	if spec.has("foam"):
		var radii := spec["foam"] as Array
		var foam := MeshInstance3D.new()
		foam.name = "Foam"
		foam.mesh = foam_mesh(float(radii[0]) * scale_factor, float(radii[1]) * scale_factor)
		foam.material_override = foam_material()
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		foam.position.y = float(spec.get("foam_y", 0.0)) * scale_factor + 0.03
		prop._foam = foam
		prop.add_child(foam)
	return prop


func _ready() -> void:
	# A stable per-prop phase from where it floats.
	phase = fposmod(global_position.x * 0.73 + global_position.z * 1.31, TAU)
	_apply(0.0)


func _process(delta: float) -> void:
	_time += delta
	_apply(_time)


## The model's offset at time `t` (seconds): bob, roll and a little pitch on the swell.
func _apply(t: float) -> void:
	var w := TAU * t / period + phase
	if _model:
		_model.position.y = sin(w) * bob
		_model.rotation.z = deg_to_rad(roll) * sin(w * 0.83 + 1.1)
		_model.rotation.x = deg_to_rad(roll * 0.5) * sin(w * 0.61 + 0.4)
	if _foam:
		# The ring swells as the hull settles (bob down = more wash).
		var s := 1.0 + 0.05 * -sin(w)
		_foam.scale = Vector3(s, 1.0, s)


## Model offset (y) right now (for tests).
func model_offset() -> float:
	return _model.position.y if _model else 0.0


## A flat elliptical ring at y 0: opaque-ish at the hull (inner radii × FOAM_TUCK), fading to
## nothing FOAM_WIDTH outside it, with a ragged outer edge. Vertex alpha carries the fade.
static func foam_mesh(rx: float, rz: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var inner: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in FOAM_SEGMENTS:
		var a := TAU * i / FOAM_SEGMENTS
		var dir := Vector3(cos(a), 0, sin(a))
		inner.append(Vector3(dir.x * rx * FOAM_TUCK, 0, dir.z * rz * FOAM_TUCK))
		mid.append(Vector3(dir.x * (rx + 0.12), 0, dir.z * (rz + 0.12)))
		var w := FOAM_WIDTH * rng.randf_range(0.6, 1.2)
		outer.append(Vector3(dir.x * (rx + w), 0, dir.z * (rz + w)))
	var white := PropFactory.color("bone")
	var c_in := Color(white, 0.85)
	var c_mid := Color(white, 0.6)
	var c_out := Color(white, 0.0)
	for i in FOAM_SEGMENTS:
		var j := (i + 1) % FOAM_SEGMENTS
		_quad(st, inner[i], inner[j], mid[j], mid[i], c_in, c_mid)
		_quad(st, mid[i], mid[j], outer[j], outer[i], c_mid, c_out)
	st.set_normal(Vector3.UP)
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, near: Color, far: Color) -> void:
	for v: Array in [[a, near], [b, near], [c, far], [a, near], [c, far], [d, far]]:
		st.set_normal(Vector3.UP)
		st.set_color(v[1])
		st.add_vertex(v[0])


static func foam_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1  # drawn over the (transparent) sea
	return mat
