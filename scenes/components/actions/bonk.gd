class_name BonkAction
extends Node
## Resolves regular ceiling contacts and underside crossings on hidden blocks.

const HIDDEN_BLOCK_PROBE_MASK := 1 << 31

@export var enabled: bool = false
@export var strength: float = 1.0


func deliver_hidden(player: BasePlayer, previous_position: Vector2) -> bool:
	if not enabled or player.is_shutdown:
		return false
	var shape := player.collision_shape.shape as RectangleShape2D
	if shape == null or player.body.global_position.y >= previous_position.y:
		return false
	var head := player.get_head_position() + Vector2(0.0001, 0)
	var previous_head := head + previous_position - player.body.global_position
	var query := PhysicsRayQueryParameters2D.create(
		previous_head + Vector2(0, 0.001), head, HIDDEN_BLOCK_PROBE_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := player.body.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.5:
		return false
	var block := _find_block(hit.collider as Node) as HiddenQuestionBlock
	if block == null or not block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength)):
		return false
	player.body.global_position.y += hit.position.y - head.y
	return true


func deliver(player: BasePlayer) -> bool:
	if not enabled or player.is_shutdown:
		return false
	if not player.body.is_on_ceiling():
		return false
	# Prefer the reference's single center-head probe over contact ordering.
	var shape := player.collision_shape.shape as RectangleShape2D
	if shape != null:
		var head := player.get_head_position()
		# Exact cell boundaries belong to the right-hand tile.
		head.x += 0.0001
		var query := PhysicsRayQueryParameters2D.create(
			head + Vector2(0, 0.5),
			head - Vector2(0, 0.5),
			player.body.collision_mask,
			[player.body.get_rid()]
		)
		var hit := player.body.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider := hit.collider as Node
			var target := _find_block(collider)
			# A used block or solid terrain under the probe must not redirect
			# the attack into a neighboring active block.
			return (
				target != null
				and target.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength))
			)
	var selected: BaseBlock = null
	var best_distance: float = INF
	for index in range(player.body.get_slide_collision_count()):
		var collision := player.body.get_slide_collision(index)
		if collision.get_normal().y < 0.5:
			continue
		var collider := collision.get_collider() as Node
		if collider == null:
			continue
		var target := _find_block(collider)
		if target == null:
			continue
		# Trust the actual ceiling contact, including partial head overlap.
		# Prefer the nearest block center; choose the right block on a tie.
		var distance := absf(target.to_local(player.body.global_position).x - 8.0)
		if (
			distance < best_distance
			or (
				is_equal_approx(distance, best_distance)
				and selected != null
				and target.global_position.x > selected.global_position.x
			)
		):
			selected = target
			best_distance = distance
	if selected != null:
		return selected.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength))
	return false


## Reference head-probe contacts can occur above the short floor-support body.
func deliver_at(player: BasePlayer, collider: Node) -> bool:
	if not enabled or player.is_shutdown or collider == null:
		return false
	var target := _find_block(collider)
	return (
		target != null and target.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength))
	)


func _find_block(collider: Node) -> BaseBlock:
	var ancestor := collider
	while ancestor != null and not ancestor is BaseBlock:
		ancestor = ancestor.get_parent()
	return ancestor as BaseBlock
