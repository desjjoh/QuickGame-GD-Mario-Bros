class_name PipeEntrance
extends TransportEntity
## Shared upright and left-facing 2x2 pipe entrance.

@export var sideways: bool = false

@export var destination_area_id: StringName = &"lower"
@export var destination_endpoint_id: StringName = &"arrival"
@export var alignment_tolerance: float = 4.0


func _physics_process(delta: float) -> void:
	super(delta)
	if not can_read_controller_input() or not is_instance_valid(_level) or _level.is_shutdown:
		return
	if not _level.can_transport():
		return
	if _level.active_area != get_parent().get_parent():
		return
	var player := _level.player
	if not is_instance_valid(player) or player.is_shutdown:
		return
	if not sideways and ControllerHandler.input_down <= 0.5:
		return
	if not can_start_entry(player):
		return
	_level.transport(player, get_destination(), self)


func can_start_entry(player: BasePlayer) -> bool:
	return is_instance_valid(player) and player.can_read_controller_input() and _can_reach_mouth(player)


func _can_reach_mouth(player: BasePlayer) -> bool:
	if (
		not entrance_enabled
		or not can_read_controller_input()
		or not is_instance_valid(player)
		or player.is_shutdown
	):
		return false
	# The reference filters Down with horizontal input before moving the player.
	if (
		not sideways
		and player.was_grounded_at_tick_start()
		and (ControllerHandler.input_left > 0.0 or ControllerHandler.input_right > 0.0)
	):
		return false
	var state := player.state_machine.current_state as PlayerState
	if state == null or not state.controls_enabled or not player.has_floor_support():
		return false
	var feet := to_local(player.body.global_position)
	if sideways:
		return (
			player.sprite != null
			and not player.sprite.flip_h
			and absf(feet.x + 6.0) <= 1.5
			and absf(feet.y - 32.0) <= alignment_tolerance
			and _touches_side_mouth(player.body)
		)
	return absf(feet.x - 16.0) <= alignment_tolerance and absf(feet.y) <= 1.0


func _touches_side_mouth(player_body: CharacterBody2D) -> bool:
	# Bridge the body's fractional clearance at the mouth.
	var contact := KinematicCollision2D.new()
	return (
		player_body.test_move(player_body.global_transform, Vector2.RIGHT * 0.5, contact)
		and contact.get_collider() == $Body
	)


func entry_position() -> Vector2:
	return to_global(Vector2(-6, 32) if sideways else Vector2(16, 0))


func entry_direction() -> Vector2:
	return Vector2.RIGHT if sideways else Vector2.DOWN


func get_destination() -> TransportDestination:
	if destination != null:
		return destination
	# Compatibility for existing PipeRoute resources and scene overrides.
	return TransportDestination.create(destination_area_id, destination_endpoint_id)


func can_start_transport(player: BasePlayer) -> bool:
	var opening := _level.opening_presentation if is_instance_valid(_level) else null
	if opening != null and opening.is_walking_into(player, self):
		return _can_reach_mouth(player)
	return can_start_entry(player)


func get_transport_state(player: BasePlayer) -> PlayerTransportState:
	return player.pipe_enter_state


func exit_position() -> Vector2:
	return to_global(Vector2(-8, 32) if sideways else Vector2(16, 0))


func exit_direction() -> Vector2:
	return Vector2.LEFT if sideways else Vector2.UP
