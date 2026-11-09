extends RefCounted
## Shared cadence and live contact rectangles for player interactions.


static func is_check_tick() -> bool:
	return Engine.get_physics_frames() % 2 == 0


static func touches(source: Area2D, target: Area2D) -> bool:
	if (
		source == null
		or not source.monitoring
		or target == null
		or not target.monitorable
		or (source.collision_mask & target.collision_layer) == 0
	):
		return false
	var source_box := source.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var target_box := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not _is_enabled_box(source_box) or not _is_enabled_box(target_box):
		return false
	# The reference counts touching edges on the current update.
	return bounds(source_box).intersects(bounds(target_box), true)


static func bounds(box: CollisionShape2D) -> Rect2:
	return box.global_transform * box.shape.get_rect()


static func _is_enabled_box(box: CollisionShape2D) -> bool:
	return box != null and not box.disabled and box.shape is RectangleShape2D
