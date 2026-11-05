class_name ClimbingComponent
extends Node
## Reference nominal speeds: -1+$20/256 and 1+$ff/256 pixels/tick.

@export var upward_speed: float = 52.5
@export var downward_speed: float = 119.765625
@export var side_offset: float = 7.0
@export var capture_probe_offset_y: float = -8.0
@export var side_switch_frames: int = 24

var _surfaces: Array[WeakRef] = []
var _surface: WeakRef
var _blocked_surface: WeakRef
var _side: float = -1.0
var _side_ticks: int = 0
var _consumed_horizontal: float = 0.0
var _capture_position: Vector2
var approach_position: Vector2


func register_surface(surface: BaseClimbable) -> void:
	for reference in _surfaces:
		if reference.get_ref() == surface:
			return
	_surfaces.append(weakref(surface))


func unregister_surface(surface: BaseClimbable) -> void:
	for index in range(_surfaces.size() - 1, -1, -1):
		if _surfaces[index].get_ref() == surface or _surfaces[index].get_ref() == null:
			_surfaces.remove_at(index)
	if _blocked_surface != null and _blocked_surface.get_ref() == surface:
		_blocked_surface = null


func find_surface(
	player: BasePlayer, from_feet: Vector2, to_feet: Vector2, after_motion: bool = true
) -> BaseClimbable:
	# Query the swept player region, independent of delayed Area2D overlap signals.
	var bounds: Rect2 = (
		player.collision_shape.global_transform * player.collision_shape.shape.get_rect()
	)
	if _blocked_surface != null:
		var blocked := _blocked_surface.get_ref() as BaseClimbable
		if not is_instance_valid(blocked) or not blocked.overlaps_body(player):
			_blocked_surface = null
	var swept := bounds.merge(Rect2(bounds.position + from_feet - to_feet, bounds.size)).grow(1.0)
	var shape := RectangleShape2D.new()
	shape.size = swept.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, swept.get_center())
	query.collision_mask = 128
	query.collide_with_bodies = false
	query.collide_with_areas = true
	for hit in player.body.get_world_2d().direct_space_state.intersect_shape(query):
		var surface := (hit.collider as Node).get_parent() as BaseClimbable
		if surface != null:
			register_surface(surface)
	var nearest: BaseClimbable = null
	var first := INF
	for index in range(_surfaces.size() - 1, -1, -1):
		var surface := _surfaces[index].get_ref() as BaseClimbable
		if not is_instance_valid(surface):
			_surfaces.remove_at(index)
			continue
		if _blocked_surface != null and _blocked_surface.get_ref() == surface:
			continue
		if not after_motion and surface is FlagpoleEntity:
			continue
		var fraction := surface.attachment_fraction(player, from_feet, to_feet)
		if fraction >= 0.0 and fraction < first:
			nearest = surface
			first = fraction
			_capture_position = from_feet.lerp(to_feet, fraction)
			approach_position = to_feet
	return nearest


func get_surface() -> BaseClimbable:
	return _surface.get_ref() as BaseClimbable if _surface != null else null


func attach(player: BasePlayer, surface: BaseClimbable) -> void:
	_surface = weakref(surface)
	_side = signf(_capture_position.x - surface.climb_top.global_position.x)
	if is_zero_approx(_side):
		_side = 1.0 if player.sprite != null and player.sprite.flip_h else -1.0
	_side_ticks = side_switch_frames
	_consumed_horizontal = 0.0
	player.body.velocity = Vector2.ZERO
	player.body.global_position = Vector2(
		surface.climb_top.global_position.x + _side * side_offset,
		surface.attachment_y(_capture_position.y)
	)
	player.face_direction(-_side)
	player.body.reset_physics_interpolation()


func notify_attached(player: BasePlayer) -> void:
	var surface := get_surface()
	if is_instance_valid(surface):
		surface.notify_attached(player)


func detach(player: BasePlayer) -> void:
	var surface := get_surface()
	_surface = null
	player.body.velocity = Vector2.ZERO
	if is_instance_valid(surface):
		# Do not immediately re-grab after stepping off the bottom.
		_blocked_surface = weakref(surface)
		surface.notify_detached(player)


func step(player: BasePlayer, axis: Vector2, delta: float) -> bool:
	var surface := get_surface()
	if not is_instance_valid(surface) or not surface.is_available():
		return false
	_side_ticks = maxi(0, _side_ticks - 1)
	var horizontal := signf(axis.x)
	var switched := false
	if is_zero_approx(horizontal):
		_side_ticks = 0
		_consumed_horizontal = 0.0
	elif horizontal != _consumed_horizontal:
		_consumed_horizontal = 0.0
		# Side is relative to the shaft: left=-1, right=+1.
		if _side_ticks == 0:
			var shift := Vector2((horizontal - _side) * side_offset, 0.0)
			if not player.body.test_move(player.body.global_transform, shift):
				_side = horizontal
				player.face_direction(-_side)
				switched = true
			_side_ticks = side_switch_frames
			# A held switch direction must not become an outward release next tick.
			_consumed_horizontal = horizontal
	var feet := player.body.global_position
	feet.x = surface.climb_top.global_position.x + _side * side_offset
	player.body.global_position = feet
	if switched:
		# A side switch is a discrete placement, not motion across the shaft.
		player.body.reset_physics_interpolation()
	var speed := (-upward_speed if axis.y < 0.0 else downward_speed) if axis.y != 0.0 else 0.0
	var target_y := clampf(
		feet.y + speed * delta,
		surface.climb_top.global_position.y,
		surface.climb_bottom.global_position.y
	)
	# Normal terrain still blocks climbing; do not use walking corner assistance.
	player.body.velocity = Vector2(0.0, (target_y - feet.y) / delta)
	player.body.move_and_slide()
	# Bounds stop climbing motion; only an explicit state change or lost surface releases it.
	return true


func place_on_side(player: BasePlayer, side: float) -> void:
	var surface := get_surface()
	if not is_instance_valid(surface):
		return
	_side = signf(side)
	player.body.global_position.x = surface.climb_top.global_position.x + _side * side_offset
	player.face_direction(-_side)
	player.body.reset_physics_interpolation()
