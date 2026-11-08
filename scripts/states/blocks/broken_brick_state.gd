extends EntityState
## Temporary solid metatile through the following player contact pass.
var _break_tick := -1


func enter() -> void:
	_break_tick = Engine.get_physics_frames()
	var debris := preload("res://scenes/components/presentation/brick_debris.gd").new()
	debris.visual_theme = entity.visual_theme
	debris.position = entity.position
	entity.get_parent().add_child(debris)
	debris.reset_physics_interpolation()
	GameHandler.add_score(50)
	entity.hide()
	entity.process_physics_priority = 1000


func process_physics(_delta: float) -> BaseState:
	if Engine.get_physics_frames() > _break_tick:
		(entity as BaseBlock).body.collision_layer = 0
		entity.queue_free()
	return null
