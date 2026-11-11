extends EntitySpawner
## One oscillating lift per area visit, independent of the enemy registry.

enum Axis { HORIZONTAL, VERTICAL }

const PARSER_X_OFFSET := 12.0

@export var axis: Axis = Axis.HORIZONTAL

var _lift: MovingLift


func update_activity(_wake_region: Rect2, _sleep_region: Rect2, theme: AreaTheme) -> void:
	if is_shutdown or not is_instance_valid(_level) or _level.is_shutdown:
		return
	if not _attempted:
		var spawn_region := _area.get_enemy_spawn_region()
		var x := global_position.x
		if x < spawn_region.position.x or x - PARSER_X_OFFSET >= spawn_region.end.x:
			return
		_attempted = true
		_spawn_lift(theme)
	elif is_instance_valid(_lift) and not _lift.is_queued_for_deletion():
		var view := _area.get_activity_region(false).grow(-_area.activation_buffer)
		var x := _lift.global_position.x
		if x < view.position.x - 73.0 or x >= view.end.x + 72.0:
			_lift.remove_offscreen()


func _spawn_lift(theme: AreaTheme) -> void:
	var actor := _instantiate_actor()
	_lift = actor as MovingLift
	if _lift == null:
		if actor != null:
			actor.free()
			push_error("Single Lift Spawner requires a MovingLift scene.")
		return
	_lift.configure_oscillation(axis == Axis.HORIZONTAL, roundi(_area.to_local(global_position).y))
	_lift.spawner_manages_activity = true
	_attach_actor(_lift, theme)
