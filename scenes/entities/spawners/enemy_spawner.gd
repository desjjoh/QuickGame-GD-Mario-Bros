class_name EnemySpawner
extends Marker2D
## Area-driven spawn point. No independent frame or physics callbacks.
@export var enemy_scene: PackedScene
@export var enabled: bool = true
@export var respawn_on_reentry: bool = true
var actor: BaseEntity
var _armed: bool = true

func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("register_enemy_spawner"):
			ancestor.register_enemy_spawner(self)
			return
		ancestor = ancestor.get_parent()

func update_activity(wake_region: Rect2, sleep_region: Rect2, theme: AreaTheme) -> void:
	if is_instance_valid(actor) and (actor.is_shutdown or not sleep_region.intersects(actor.get_activity_rect())):
		_dispose_actor()
	if not sleep_region.has_point(global_position) and respawn_on_reentry:
		_armed = true
	if not enabled:
		_dispose_actor()
		return
	if is_instance_valid(actor) or not _armed or enemy_scene == null or not wake_region.has_point(global_position): return
	_armed = false
	var instance := enemy_scene.instantiate()
	if not instance is BaseEntity or instance is BasePlayer:
		instance.free()
		push_error("EnemySpawner requires a non-player BaseEntity scene.")
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
