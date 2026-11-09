extends Node2D
## Collects a coin in the cell above and delivers one upward actor hit.

@export var width := 16.0


func strike(source: BaseEntity, attacker: BaseEntity) -> void:
	if is_instance_valid(attacker) and attacker is BasePlayer:
		_collect_coin_above(attacker)
	var strip := RectangleShape2D.new()
	strip.size = Vector2(width, 4)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = strip
	query.transform = global_transform
	query.collision_mask = BlockHitReceiver.QUERY_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var level := BaseLevel.containing(source)
	var registry: LevelSpawnRegistry = level.spawn_registry if level != null else null
	var candidates: Array[Dictionary] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var receiver := result.collider as BlockHitReceiver
		if receiver != null:
			var entity: Node = receiver
			while entity != null and not entity is BaseEntity:
				entity = entity.get_parent()
			var category: StringName = &""
			var priority := 2
			if entity is BaseEnemy:
				category = &"enemy"
				priority = 0
			elif entity is PowerUp:
				category = &"power_up"
				priority = 1
			var slot := registry.get_slot(category, entity) if registry != null else -1
			candidates.append({"receiver": receiver, "category": priority, "slot": slot})
	candidates.sort_custom(_comes_before)
	var origin := attacker if is_instance_valid(attacker) else source
	for candidate in candidates:
		if not is_instance_valid(candidate.receiver):
			continue
		var receiver: BlockHitReceiver = candidate.receiver
		if receiver.is_queued_for_deletion():
			continue
		var hit := EntityHit.new(origin, &"block_bump", Vector2.UP)
		hit.struck_block = source
		if receiver.receive_hit(hit):
			return


func _collect_coin_above(player: BasePlayer) -> void:
	var query := PhysicsPointQueryParameters2D.new()
	# BlockImpact is centered on the block's top edge.
	query.position = to_global(Vector2(0, -8))
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var canvas := get_canvas_layer_node()
	query.canvas_instance_id = canvas.get_instance_id() if canvas != null else 0
	for result in get_world_2d().direct_space_state.intersect_point(query):
		var coin := (result.collider as Node).get_parent().get_parent() as WorldCoin
		if coin != null and coin.collect_from_block(player):
			return


func _comes_before(first: Dictionary, second: Dictionary) -> bool:
	if first.category != second.category:
		return first.category < second.category
	if first.slot != second.slot:
		if first.slot < 0:
			return false
		if second.slot < 0:
			return true
		return first.slot < second.slot
	# Unregistered actors follow registered actors within their category.
	# Tree order keeps authored/test actors deterministic without claiming capacity.
	return second.receiver.is_greater_than(first.receiver)
