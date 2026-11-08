class_name EnemySpawner
extends Marker2D
## Area-driven spawn point. No independent frame or physics callbacks.
@export var enemy_scene: PackedScene
@export var enabled: bool = true
@export var respawn_on_reentry: bool = true
var actor: BaseEntity
var _armed: bool = true
var _failed_activation := false
var _level: BaseLevel


func _ready() -> void:
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


func update_activity(wake_region: Rect2, sleep_region: Rect2, theme: AreaTheme) -> void:
	if (
		is_instance_valid(actor)
		and (
			actor.is_shutdown
			or (not actor is BaseEnemy and not sleep_region.intersects(actor.get_activity_rect()))
		)
	):
		_dispose_actor()
	if not sleep_region.has_point(global_position) and respawn_on_reentry:
		_armed = true
	if not enabled:
		_dispose_actor()
		return
	if (
		is_instance_valid(actor)
		or not _armed
		or _failed_activation
		or not wake_region.has_point(global_position)
	):
		return
	_armed = false
	if enemy_scene == null or (_level != null and not _level.has_spawn_capacity(&"enemy")):
		_failed_activation = true
		return
	var instance := enemy_scene.instantiate()
	if not instance is BaseEntity or instance is BasePlayer:
		_failed_activation = true
		instance.free()
		push_error("EnemySpawner requires a non-player BaseEntity scene.")
		return
	if _level != null and not _level.try_claim_spawn_slot(&"enemy", instance):
		_failed_activation = true
		instance.free()
		return
	actor = instance as BaseEntity
	actor.position = Vector2.ZERO
	actor.visual_theme = theme
	add_child(actor)
	actor.reset_physics_interpolation()


func _dispose_actor() -> void:
	if not is_instance_valid(actor):
		actor = null
		return
	var previous := actor
	actor = null
	previous.shutdown()
	previous.queue_free()


func _exit_tree() -> void:
	_dispose_actor()
