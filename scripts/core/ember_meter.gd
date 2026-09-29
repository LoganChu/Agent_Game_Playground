class_name EmberMeter
extends RefCounted
## The Wakebearer's ember while walking the Greying: drains with fog depth, refills in the
## clear. Not saved — it is always full again a few seconds after leaving the fog.

signal emptied

## 1 = full, 0 = spent ("you forget why you came").
var ember := 1.0
## Multiplies drain speed (tests and the smoke test speed it up).
var drain_scale := 1.0


## Advances by `delta` seconds at fog `depth` (0..1). Emits `emptied` once when the ember
## runs out; the caller turns the player back and calls `refill()`.
func step(delta: float, depth: float) -> void:
	if depth >= Greying.CLEAR_DEPTH:
		if ember <= 0.0:
			return
		ember = maxf(0.0, ember - depth * delta * drain_scale / Greying.DRAIN_SECONDS)
		if ember <= 0.0:
			emptied.emit()
	else:
		ember = minf(1.0, ember + delta / Greying.REFILL_SECONDS)


func refill() -> void:
	ember = 1.0


func is_full() -> bool:
	return ember >= 1.0
