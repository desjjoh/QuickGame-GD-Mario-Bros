@tool
extends EntitySpawner
## One oscillating lift per area visit, independent of the enemy registry.

enum Axis { HORIZONTAL, VERTICAL }

const PARSER_X_OFFSET := 12.0
const PREVIEW := preload("res://scenes/entities/spawners/lift_preview.gd")

@export var axis: Axis = Axis.HORIZONTAL:
	set(value):
		axis = value
		if Engine.is_editor_hint():
			queue_redraw()
@export var platform_width: MovingLift.Width = MovingLift.Width.MEDIUM:
	set(value):
		platform_width = value
		if Engine.is_editor_hint():
			queue_redraw()
## Use -1 for the original oscillation, 0 for a fixed platform, or a distance from the marker.
@export_range(-1, 4096, 1, "or_greater", "suffix:px") var travel_distance := -1:
	set(value):
		travel_distance = value
		if Engine.is_editor_hint():
			queue_redraw()

var _lift: MovingLift


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_notify_transform(true)
		queue_redraw()
		return
	super()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevelArea:
		ancestor = ancestor.get_parent()
	var area := ancestor as BaseLevelArea
	var area_y := roundi(area.to_local(global_position).y) if area != null else roundi(position.y)
	var span := _preview_span(area_y)
	var travel_axis := Vector2.RIGHT if axis == Axis.HORIZONTAL else Vector2.DOWN
	var width := platform_width * MovingLift.TILE_WIDTH
	PREVIEW.draw_path(self, travel_axis * span.x, travel_axis * span.y, width)
	PREVIEW.draw_surface(self, Vector2.ZERO, width)


func _preview_span(area_y: int) -> Vector2i:
	if travel_distance >= 0:
		if axis == Axis.HORIZONTAL:
			return Vector2i(-travel_distance, 0)
		return Vector2i(0, travel_distance)
	var displacement := 0
	var span := Vector2i.ZERO
	if axis == Axis.HORIZONTAL:
		var oscillator := MovingLift.HORIZONTAL_OSCILLATION.new(MovingLift.HORIZONTAL_MAX_SPEED)
		for tick in range(256):
			displacement += oscillator.step(tick)
			span = Vector2i(mini(span.x, displacement), maxi(span.y, displacement))
	else:
		var oscillator := MovingLift.VERTICAL_OSCILLATION.new(
			MovingLift.VERTICAL_DOWN_FORCE, MovingLift.VERTICAL_UP_FORCE, MovingLift.VERTICAL_MAX_SPEED
		)
		var anchors := MovingLift.vertical_anchors(area_y)
		# Sample a representative cycle from rest using the same motion as the live actor.
		for tick in range(1024):
			displacement += oscillator.step(displacement, anchors.x, anchors.y, tick)
			span = Vector2i(mini(span.x, displacement), maxi(span.y, displacement))
	return span


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
	_lift.platform_width = platform_width
	_lift.travel_distance = travel_distance
	_lift.spawner_manages_activity = true
	_attach_actor(_lift, theme)
