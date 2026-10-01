class_name Layers
extends RefCounted
## Physics layer numbers (1-based, as used by set_collision_layer_value).

const WORLD := 1
const PLAYER := 2
const INTERACTABLE := 3
## Blocks only the camera's spring arm: tall props' full bounds (roofs, eaves, canopies),
## which their walk-blocking colliders don't cover.
const CAMERA := 4
