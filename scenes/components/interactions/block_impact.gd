extends Node2D
## Collects a coin in the cell above and delivers one upward actor hit.

@export var width := 16.0

var _source: BaseBlock
var _attacker: BaseEntity
var _shatter_tick := -1


func _ready() -> void:
	# Resolve late arrivals after actor movement and before a broken brick frees itself.
	process_physics_priority = 1
	set_physics_process(false)


func strike(source: BaseBlock, attacker: BaseEntity) -> void:
	if is_instance_valid(attacker) and attacker is BasePlayer:
		_collect_coin_above(attacker)
	_source = source
	_attacker = attacker
	_shatter_tick = -1 if source.bounce.is_running() else Engine.get_physics_frames()
	if _try_hit_actor():
		_close()
	else:
		set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _source.is_shutdown or (_shatter_tick < 0 and not _source.bounce.is_running()):
		_close()
		return
	# The brick removes its temporary tile after this pass on the following tick.
	var final_pass := _shatter_tick >= 0 and Engine.get_physics_frames() > _shatter_tick
	if _try_hit_actor() or final_pass:
		_close()


func _close() -> void:
	set_physics_process(false)
	_source = null
	_attacker = null


func _try_hit_actor() -> bool:
	var strip := global_transform * Rect2(-width / 2.0, -2.0, width, 4.0)
	var canvas := get_canvas()
	var level := BaseLevel.containing(_source)
	var registry: LevelSpawnRegistry = level.spawn_registry if level != null else null
	var candidates: Array[Dictionary] = []
	# Read transforms directly so movement this tick is visible to the retry.
	for receiver: BlockHitReceiver in get_tree().get_nodes_in_group(BlockHitReceiver.GROUP):
		if receiver.get_canvas() != canvas or not receiver.overlaps_strip(strip):
			continue
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
	var origin := _attacker if is_instance_valid(_attacker) else _source
	for candidate in candidates:
		if not is_instance_valid(candidate.receiver):
			continue
		var receiver: BlockHitReceiver = candidate.receiver
		if receiver.is_queued_for_deletion():
			continue
		var hit := EntityHit.new(origin, &"block_bump", Vector2.UP)
		hit.struck_block = _source
		if receiver.receive_hit(hit):
			return true
	return false


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
