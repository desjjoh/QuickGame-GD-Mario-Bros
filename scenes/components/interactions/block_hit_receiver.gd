class_name BlockHitReceiver
extends Area2D
## A narrow foot contact used by blocks that are struck from below.

const GROUP := &"block_hit_receivers"

## The entity owns eligibility and reactions; delivery only reports its result.
var hit_handler: Callable

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)


func overlaps_strip(strip: Rect2) -> bool:
	return (
		not _shape.disabled
		and _shape.shape != null
		and strip.intersects(_shape.global_transform * _shape.shape.get_rect())
	)


func receive_hit(hit: EntityHit) -> bool:
	if hit == null or not hit_handler.is_valid():
		return false
	return hit_handler.call(hit)
