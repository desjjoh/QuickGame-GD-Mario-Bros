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
	if not sideways and (ControllerHandler.input_down <= 0.5 or ControllerHandler.input_up > 0.5):
		return
	if not can_start_entry(player):
		return
	_level.transport(player, get_destination(), self)


func can_start_entry(player: BasePlayer) -> bool:
	if (
		not entrance_enabled
		or not can_read_controller_input()
		or not is_instance_valid(player)
		or player.is_shutdown
	):
		return false
	# Check each direction independently: opposing buttons must not cancel
	# into a neutral axis and accidentally allow pipe entry.
	if not sideways and (ControllerHandler.input_left > 0.0 or ControllerHandler.input_right > 0.0):
		return false
	var state := player.state_machine.current_state as PlayerState
	if state == null or not state.controls_enabled or not player.body.is_on_floor():
		return false
	var feet := to_local(player.body.global_position)
	if sideways:
		return (
			ControllerHandler.input_right > 0.5
			and ControllerHandler.input_left <= 0.0
			and absf(feet.x + 6.0) <= 1.5
			and absf(feet.y - 32.0) <= alignment_tolerance
		)
	return absf(feet.x - 16.0) <= alignment_tolerance and absf(feet.y) <= 1.0


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
	return can_start_entry(player)


func get_transport_state(player: BasePlayer) -> PlayerTransportState:
	return player.pipe_enter_state


func exit_position() -> Vector2:
	return to_global(Vector2(-8, 32) if sideways else Vector2(16, 0))


func exit_direction() -> Vector2:
	return Vector2.LEFT if sideways else Vector2.UP
