extends Node2D
## Delivers one upward hit to each receiver touching this block's top edge.

@export var width := 16.0


func strike(source: BaseEntity, attacker: BaseEntity) -> void:
	var strip := RectangleShape2D.new()
	strip.size = Vector2(width, 4)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = strip
	query.transform = global_transform
	query.collision_mask = BlockHitReceiver.QUERY_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var receiver := result.collider as BlockHitReceiver
		if receiver != null:
			var origin := attacker if is_instance_valid(attacker) else source
			receiver.receive_hit(EntityHit.new(origin, &"block_bump", Vector2.UP))
