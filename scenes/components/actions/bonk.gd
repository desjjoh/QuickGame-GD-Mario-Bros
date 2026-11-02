class_name BonkAction
extends Node
## Called only for an upward ceiling collision, after character movement.

@export var enabled: bool = false
@export var strength: float = 1.0


func deliver(player: BasePlayer) -> bool:
	if not enabled or player.is_shutdown:
		return false
	if not player.body.is_on_ceiling():
		return false
	# Prefer the reference's single center-head probe over contact ordering.
	var shape := player.collision_shape.shape as RectangleShape2D
	if shape != null:
		var head := Vector2(player.body.global_position.x, player.collision_shape.global_position.y - shape.size.y / 2.0)
		# Exact cell boundaries belong to the right-hand tile.
		head.x += 0.0001
		var query := PhysicsRayQueryParameters2D.create(head + Vector2(0, 0.5), head - Vector2(0, 0.5), player.body.collision_mask, [player.body.get_rid()])
		var hit := player.body.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider := hit.collider as Node
			var target := collider.get_parent() as BaseBlock if collider != null else null
			# A used block or solid terrain under the probe must not redirect
			# the attack into a neighboring active block.
			return target != null and target.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength))
	var selected: BaseBlock
	var best_distance: float = INF
	for index in range(player.body.get_slide_collision_count()):
		var collision := player.body.get_slide_collision(index)
		if collision.get_normal().y < 0.5:
			continue
		var collider := collision.get_collider() as Node
		if collider == null:
			continue
		var target := collider.get_parent() as BaseBlock
		if target == null:
			continue
		# Trust the actual ceiling contact, including partial head overlap.
		# Prefer the nearest block center; choose the right block on a tie.
		var distance := absf(target.to_local(player.body.global_position).x - 8.0)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and selected != null and target.global_position.x > selected.global_position.x):
			selected = target
			best_distance = distance
	if selected != null:
		return selected.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength))
	return false
