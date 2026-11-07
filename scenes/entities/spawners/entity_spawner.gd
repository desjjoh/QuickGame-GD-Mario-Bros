class_name EntitySpawner
extends BaseEntity
## Painted placement that attempts to create its actors once per area visit.

@export var actor_scene: PackedScene
@export var spawn_category: StringName
@export var actor_offsets: Array[Vector2] = [Vector2.ZERO]

var _level: BaseLevel
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
		area.register_spawner(self)


func update_activity(wake_region: Rect2, _sleep_region: Rect2, theme: AreaTheme) -> void:
	if is_shutdown or _attempted or _consumed or not wake_region.has_point(global_position):
		return
	_attempted = true
	for offset in actor_offsets:
		if not _spawn_actor(offset, theme):
			break


func _spawn_actor(offset: Vector2, theme: AreaTheme) -> bool:
	if _level != null and not _level.has_spawn_capacity(spawn_category):
		return false
	var instance := actor_scene.instantiate() if actor_scene != null else null
	var actor := instance as SpawnableEntity
	if actor == null:
		if instance != null:
			instance.free()
		push_error("EntitySpawner requires a SpawnableEntity scene.")
		return false
	if _level != null and not _level.try_claim_spawn_slot(spawn_category, actor):
		actor.free()
		return false
	actor.position = offset
	actor.visual_theme = theme
	actor.consumed.connect(_on_actor_consumed.bind(actor), CONNECT_ONE_SHOT)
	add_child(actor)
	actor.reset_physics_interpolation()
	return true


func _on_actor_consumed(actor: SpawnableEntity) -> void:
	_consumed = actor.persist_progress


func capture_area_state() -> Dictionary:
	return {"consumed": true} if _consumed else {}


func restore_area_state(data: Dictionary) -> void:
	_consumed = data.get("consumed", false)
