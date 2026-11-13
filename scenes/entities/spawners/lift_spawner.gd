@tool
extends EntitySpawner
## One authored lane, with a separate lifecycle from the enemy registry.

const CYCLE_HEIGHT := 256
const LIFT_X_OFFSET := 12.0
const PREVIEW := preload("res://scenes/entities/spawners/lift_preview.gd")

@export var direction: MovingLift.Direction = MovingLift.Direction.UP:
	set(value):
		direction = value
		if Engine.is_editor_hint():
			queue_redraw()
@export var platform_width: MovingLift.Width = MovingLift.Width.MEDIUM:
	set(value):
		platform_width = value
		if Engine.is_editor_hint():
			queue_redraw()
## Starting distances from this marker, in pixels along the travel direction.
@export var initial_offsets: Array[int] = [0]:
	set(value):
		initial_offsets = value
		if Engine.is_editor_hint():
			queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		queue_redraw()
		return
	super()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		super()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var width := platform_width * MovingLift.TILE_WIDTH
	PREVIEW.draw_path(self, Vector2.ZERO, Vector2(0, CYCLE_HEIGHT * direction), width)
	for offset in initial_offsets:
		var origin := Vector2(0, clampi(offset, 0, CYCLE_HEIGHT - 1) * direction)
		PREVIEW.draw_surface(self, origin, width)


func update_activity(_wake_region: Rect2, _sleep_region: Rect2, theme: AreaTheme) -> void:
	if is_shutdown or not is_instance_valid(_level) or _level.is_shutdown:
		return
	var x := global_position.x
	if not _attempted:
		var wake_region := _area.get_enemy_spawn_region()
		# The reference parses a lift 12 px before its left artwork edge.
		if x < wake_region.position.x or x - LIFT_X_OFFSET >= wake_region.end.x:
			return
		_attempted = true
		for offset in initial_offsets:
			_spawn_lift(clampi(offset, 0, CYCLE_HEIGHT - 1) * direction, theme)
		return
	var view := _area.get_activity_region(false).grow(-_area.activation_buffer)
	var outside_lane := x < view.position.x - 73.0 or x >= view.end.x + 72.0
	for child in get_children():
		var lift := child as MovingLift
		if lift == null or lift.is_queued_for_deletion():
			continue
		if outside_lane:
			lift.remove_offscreen()
		elif lift.reached_outgoing_edge():
			lift.remove_offscreen()
			if lift.is_queued_for_deletion():
				_spawn_lift(lift.position.y - CYCLE_HEIGHT * direction, theme, lift.fraction)


func _spawn_lift(y: float, theme: AreaTheme, fraction := 0) -> void:
	var actor := _instantiate_actor()
	var lift := actor as MovingLift
	if lift == null:
		if actor != null:
			actor.free()
		return
	lift.position = Vector2(0, y)
	lift.direction = direction
	lift.outgoing_y = CYCLE_HEIGHT * direction
	lift.fraction = fraction
	lift.platform_width = platform_width
	lift.spawner_manages_activity = true
	_attach_actor(lift, theme)
