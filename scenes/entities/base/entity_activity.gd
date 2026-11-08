class_name EntityActivity
extends RefCounted
## Entity-local bookkeeping. The owner is passed per call, avoiding an ownership cycle.

var _activity_geometry: Array[WeakRef] = []
var _physics_suspended: bool = false
var _suspended_frames: Dictionary[int, Dictionary] = {}
var _paused_animations: Dictionary[int, Dictionary] = {}
var _suspended_physics: Dictionary[int, Dictionary] = {}


func apply_activity_suspension(entity: BaseEntity, value: bool) -> void:
	if value:
		_suspend_frame_branch(entity, entity)
		for child in _get_owned_nodes(entity):
			if not child is AnimationPlayer and not child is AnimatedSprite2D:
				continue
			_paused_animations[child.get_instance_id()] = {
				"node": weakref(child), "speed": child.speed_scale
			}
			child.speed_scale = 0.0
	else:
		for record: Dictionary in _suspended_frames.values():
			var node := (record.node as WeakRef).get_ref() as Node
			if is_instance_valid(node):
				node.set_process(record.enabled)
		_suspended_frames.clear()
		for record: Dictionary in _paused_animations.values():
			var node := (record.node as WeakRef).get_ref() as Node
			if is_instance_valid(node):
				node.set("speed_scale", record.speed)
		_paused_animations.clear()
	for child in _get_owned_nodes(entity):
		if child is SynchronizedAnimation:
			child.set_activity_suspended(value)


func sync_physics(entity: BaseEntity, suspended: bool) -> void:
	if suspended != _physics_suspended:
		_physics_suspended = suspended
		if suspended:
			_suspend_physics_branch(entity, entity)
		else:
			for record: Dictionary in _suspended_physics.values():
				var node := (record.node as WeakRef).get_ref() as Node
				if is_instance_valid(node):
					node.set_physics_process(record.enabled)
			_suspended_physics.clear()


func clear() -> void:
	_suspended_physics.clear()
	_suspended_frames.clear()
	_paused_animations.clear()
	_activity_geometry.clear()


func _suspend_frame_branch(entity: BaseEntity, node: Node) -> void:
	if node != entity and node is BaseEntity:
		return
	_suspended_frames[node.get_instance_id()] = {
		"node": weakref(node), "enabled": node.is_processing()
	}
	node.set_process(false)
	for child in node.get_children():
		_suspend_frame_branch(entity, child)


## Nested entities have independent area activity and suspension ownership.
func _get_owned_nodes(entity: BaseEntity) -> Array[Node]:
	var result: Array[Node] = []
	_append_owned_nodes(entity, result)
	return result


func _append_owned_nodes(parent: Node, result: Array[Node]) -> void:
	for child in parent.get_children():
		if child is BaseEntity:
			continue
		result.append(child)
		_append_owned_nodes(child, result)


## Call again after dynamically adding or replacing geometry.
func refresh_geometry(entity: BaseEntity) -> void:
	_activity_geometry.clear()
	for child in _get_owned_nodes(entity):
		if child is CollisionShape2D or child is Sprite2D or child is TileMapLayer:
			_activity_geometry.append(weakref(child))


## Includes moving child bodies rather than assuming the entity root moves.
func get_rect(entity: BaseEntity) -> Rect2:
	var bounds := Rect2(entity.global_position, Vector2.ZERO)
	var found := false
	for reference: WeakRef in _activity_geometry:
		var child := reference.get_ref() as Node2D
		if not is_instance_valid(child):
			continue
		var local_rect: Rect2
		if child is CollisionShape2D and child.shape != null:
			local_rect = child.shape.get_rect()
		elif child is Sprite2D and child.texture != null:
			local_rect = child.get_rect()
		elif child is TileMapLayer and child.tile_set != null:
			var cells: Rect2i = (child as TileMapLayer).get_used_rect()
			local_rect = Rect2(Vector2(cells.position), Vector2(cells.size))
			local_rect.position *= Vector2(child.tile_set.tile_size)
			local_rect.size *= Vector2(child.tile_set.tile_size)
		else:
			continue
		var world_rect: Rect2 = child.global_transform * local_rect
		bounds = bounds.merge(world_rect) if found else world_rect
		found = true
	return bounds if found else Rect2(entity.global_position - Vector2.ONE, Vector2(2, 2))


func _suspend_physics_branch(entity: BaseEntity, node: Node) -> void:
	if node != entity and node is BaseEntity:
		return
	_suspended_physics[node.get_instance_id()] = {
		"node": weakref(node), "enabled": node.is_physics_processing()
	}
	node.set_physics_process(false)
	for child in node.get_children():
		_suspend_physics_branch(entity, child)
