class_name EntitySpawner
extends BaseEntity
## Painted placement that attempts to create its actors once per area visit.

@export var actor_scene: PackedScene
@export var spawn_category: StringName
@export var actor_offsets: Array[Vector2] = [Vector2.ZERO]

var _level: BaseLevel
var _area: BaseLevelArea
var _attempted := false
var _consumed := false


func _ready() -> void:
	super()
	set_process(false)
	set_physics_process(false)
	var ancestor := get_parent()
	var area: BaseLevelArea
	while ancestor != null:
		if ancestor is BaseLevelArea:
			area = ancestor
		elif ancestor is BaseLevel:
			_level = ancestor
			break
		ancestor = ancestor.get_parent()
	if area != null:
		_area = area
		area.register_spawner(self)


func update_activity(wake_region: Rect2, sleep_region: Rect2, theme: AreaTheme) -> void:
	if is_shutdown or _attempted or _consumed or not wake_region.has_point(_spawn_trigger()):
		return
	_attempted = true
	for offset in actor_offsets:
		if not _spawn_actor(offset, sleep_region, theme):
			break


func skip_spawn_before(right_edge: float) -> void:
	if _spawn_trigger().x < right_edge:
		_attempted = true


func _spawn_trigger() -> Vector2:
	var trigger := global_position
	if spawn_category == &"enemy" and actor_offsets.size() > 1:
		trigger.x += 48.0
	return trigger


func _spawn_actor(offset: Vector2, sleep_region: Rect2, theme: AreaTheme) -> bool:
	if _level != null and not _level.has_spawn_capacity(spawn_category):
		return false
	var actor := _instantiate_actor()
	if actor == null:
		return false
	if _level != null and not _level.try_claim_spawn_slot(spawn_category, actor):
		actor.free()
		return false
	actor.position = offset
	if spawn_category == &"enemy" and actor_offsets.size() > 1 and is_instance_valid(_area):
		actor.position.x += _area.get_enemy_group_origin_x() - global_position.x
	_attach_actor(actor, theme)
	# A group activates at its marker. Members inside the outer buffer start
	# together even when an offset puts one beyond the inner wake region.
	if actor_offsets.size() > 1 and sleep_region.intersects(actor.get_activity_rect()):
		actor.set_activity_suspended(false)
	return true


func _instantiate_actor() -> SpawnableEntity:
	var instance := actor_scene.instantiate() if actor_scene != null else null
	var actor := instance as SpawnableEntity
	if actor == null:
		if instance != null:
			instance.free()
		push_error("EntitySpawner requires a SpawnableEntity scene.")
	return actor


func _attach_actor(actor: SpawnableEntity, theme: AreaTheme) -> void:
	actor.visual_theme = theme
	actor.consumed.connect(_on_actor_consumed.bind(actor), CONNECT_ONE_SHOT)
	add_child(actor)
	if is_instance_valid(_area):
		actor.set_gameplay_suspended(_area.actors_suspended)
	actor.reset_physics_interpolation()


func _on_actor_consumed(actor: SpawnableEntity) -> void:
	_consumed = actor.persist_progress


func capture_area_state() -> Dictionary:
	return {"consumed": true} if _consumed else {}


func restore_area_state(data: Dictionary) -> void:
	_consumed = data.get("consumed", false)
