class_name Interactable
extends Area3D
## Something the player can press "interact" on when nearby. Subclasses override interact().

## Shown in the HUD, e.g. "Talk to Mara".
@export var prompt := "Interact"
## Radius of the trigger sphere.
@export var reach := 1.8


func _ready() -> void:
	collision_layer = 0
	set_collision_layer_value(Layers.INTERACTABLE, true)
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	shape.shape = sphere
	shape.position = Vector3(0, 1.0, 0)
	add_child(shape)


func can_interact() -> bool:
	return true


func interact() -> void:
	pass
