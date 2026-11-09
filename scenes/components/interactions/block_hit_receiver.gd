class_name BlockHitReceiver
extends Area2D
## A narrow foot contact used by blocks that are struck from below.

const QUERY_LAYER := 1 << 9
## The entity owns eligibility and reactions; delivery only reports its result.
var hit_handler: Callable


func receive_hit(hit: EntityHit) -> bool:
	if hit == null or not hit_handler.is_valid():
		return false
	return hit_handler.call(hit)
