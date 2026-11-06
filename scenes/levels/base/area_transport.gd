class_name AreaTransport
extends Node
## Owns the trip and its callbacks for one level instance.

var input_locked: bool = false
var pending: bool = false
var _players_draw_index: int = -1
var _transport_state: PlayerTransportState = null
var _transport_trip: Dictionary = {}
var _transport_exiting: bool = false
var _transport_phase: int = 0
var _transport_completion_callback: Callable

@onready var level: BaseLevel = get_parent()


func has_active_state() -> bool:
	return _transport_state != null


func advance() -> bool:
	if _transport_state != null:
		if (
			not _transport_trip_valid()
			or level.player.state_machine.current_state != _transport_state
		):
			cancel(true)
		return true
	if (
		ControllerHandler.input_down <= 0.5
		and ControllerHandler.input_up <= 0.5
		and ControllerHandler.input_left <= 0.5
		and ControllerHandler.input_right <= 0.5
	):
		input_locked = false
	return false


func _resolve_area(id: StringName) -> BaseLevelArea:
	var selected: BaseLevelArea = null
	for area in level.get_node("Areas").get_children():
		if area is BaseLevelArea and area.area_id == id:
			if selected != null:
				return null
			selected = area
	return selected


func _resolve_target(area: BaseLevelArea, id: StringName) -> Object:
	# Reserved main-area destination follows the real level spawn marker.
	if area == level.get_node("Areas/MainArea") and id == &"player_spawn":
		return level.player_spawn if is_instance_valid(level.player_spawn) else null
	var definition := area.resolve_transport_target(id)
	if definition is TransportPlacement:
		if area.runtime_loaded:
			var target := area.find_transport_entity(id)
			if target == null or target.is_shutdown or not target.exit_enabled:
				return null
		else:
			var progress := GameHandler.get_area_progress(level._progress_key, area.area_id)
			var entity_state: Dictionary = progress.get("entities", {}).get(
				area.transport_entity_name(definition), {}
			)
			if entity_state.get("removed", false):
				return null
	return definition


func begin(
	traveler: BasePlayer,
	destination: TransportDestination,
	source: TransportEntity,
	animate_arrival: bool
) -> bool:
	if (
		level.is_shutdown
		or level.transition_in_progress
		or level.death_in_progress
		or level.completion_in_progress
		or pending
		or not is_instance_valid(traveler)
		or traveler != level.player
		or traveler.is_shutdown
		or destination == null
	):
		return false
	if destination.area_id == &"" or destination.target_id == &"":
		return false
	var area := _resolve_area(destination.area_id)
	if area == null:
		return false
	var definition := _resolve_target(area, destination.target_id)
	if (
		definition == null
		or (area == level.active_area and destination.target_id == level.active_target_id)
	):
		return false
	var state: PlayerTransportState = null
	if source != null:
		if (
			not is_instance_valid(source)
			or not source.is_inside_tree()
			or not level.can_transport()
			or source.get_parent().get_parent() != level.active_area
			or not source.can_start_transport(traveler)
		):
			return false
		state = source.get_transport_state(traveler)
		if state == null:
			return false
	_transport_trip = {
		"area": weakref(area),
		"definition": weakref(definition),
		"area_id": destination.area_id,
		"target_id": destination.target_id,
		"source": weakref(source) if source != null else null,
		"animate": animate_arrival
	}
	pending = true
	_transport_phase += 1
	if source == null:
		_finish_transport.call_deferred(_transport_phase)
	else:
		state.configure(source.entry_position(), source.entry_direction())
		_start_transport_state(state)
	return pending


func _start_transport_state(state: PlayerTransportState) -> void:
	_transport_state = state
	_transport_phase += 1
	_transport_completion_callback = _on_transport_finished.bind(_transport_phase)
	state.travel_finished.connect(_transport_completion_callback)
	state.exited.connect(_restore_player_draw_order)
	_players_draw_index = level.players.get_index()
	level.move_child(level.players, level.get_node("Areas").get_index())
	var suspended := level.player.state_machine.gameplay_suspended
	level.player.state_machine.gameplay_suspended = false
	var changed := level.player.state_machine.change_state(state)
	level.player.state_machine.gameplay_suspended = suspended
	if not changed:
		cancel(true)


func _transport_trip_valid() -> bool:
	if (
		_transport_trip.is_empty()
		or not is_instance_valid(level.player)
		or level.player.is_shutdown
	):
		return false
	var area := (_transport_trip["area"] as WeakRef).get_ref() as BaseLevelArea
	var definition: Object = (_transport_trip["definition"] as WeakRef).get_ref()
	if (
		not is_instance_valid(area)
		or not is_instance_valid(definition)
		or _resolve_area(_transport_trip["area_id"]) != area
		or _resolve_target(area, _transport_trip["target_id"]) != definition
	):
		return false
	if not _transport_exiting and _transport_trip["source"] != null:
		var source := (_transport_trip["source"] as WeakRef).get_ref() as TransportEntity
		return is_instance_valid(source) and not source.is_shutdown
	return true


func _arrival_data(area: BaseLevelArea, target_id: StringName, animate: bool) -> Dictionary:
	var definition := _resolve_target(area, target_id)
	if definition == level.player_spawn:
		return {
			"position": level.player_spawn.global_position,
			"direction": Vector2.ZERO,
			"distance": 0.0,
			"state": null,
			"endpoint": null
		}
	if definition is TransportPlacement:
		var target := area.find_transport_entity(target_id)
		if target == null:
			return {}
		var state := target.get_transport_state(level.player)
		if animate and state == null:
			return {}
		return {
			"position": target.exit_position(),
			"direction": target.exit_direction(),
			"distance": target.exit_distance,
			"state": state if animate else null,
			"endpoint": null
		}
	if definition is AreaEndpoint:
		# Existing standalone spawns remain valid; animated legacy markers adapt to pipe presentation.
		return {
			"position": definition.global_position,
			"direction": definition.get_exit_vector(),
			"distance": definition.exit_distance,
			"state": level.player.pipe_enter_state if animate and definition.animate_exit else null,
			"endpoint": definition
		}
	return {}


func _on_transport_finished(phase: int) -> void:
	_finish_transport.call_deferred(phase)


func _finish_transport(phase: int) -> void:
	if phase != _transport_phase or level.is_shutdown or not pending:
		return
	if not _transport_exiting and GameHandler.transitions.available():
		if (
			GameHandler.transitions.begin(
				level,
				_commit_transport_under_cover.bind(phase),
				&"area",
				_area_transition_complete,
				_area_transition_valid
			)
			== 0
		):
			cancel(true)
		elif GameHandler.transitions.busy:
			MusicHandler.stop_area(level)
		return
	_commit_transport(phase)


func _commit_transport_under_cover(phase: int) -> bool:
	if phase != _transport_phase or level.is_shutdown or GameHandler.current_level != level:
		return false
	if not _transport_trip_valid():
		return false
	_commit_transport(phase, true)
	return not level.is_shutdown and GameHandler.current_level == level


func _area_transition_valid() -> bool:
	return (
		not level.is_shutdown
		and GameHandler.current_level == level
		and (not pending or _transport_trip_valid())
	)


func _area_transition_complete(success: bool) -> void:
	if not success and not level.is_shutdown:
		cancel(true)
	level._play_area_music()


func _start_player_state() -> void:
	var suspended := level.player.state_machine.gameplay_suspended
	level.player.state_machine.gameplay_suspended = false
	level.player.state_machine.start()
	level.player.state_machine.gameplay_suspended = suspended


func _commit_transport(phase: int, under_cover: bool = false) -> void:
	if phase != _transport_phase or level.is_shutdown or not pending:
		return
	if (
		not _transport_trip_valid()
		or (
			_transport_state != null
			and level.player.state_machine.current_state != _transport_state
		)
	):
		cancel(true)
		return
	if _transport_exiting:
		_transport_state.commit_transfer()
		_disconnect_transport_state()
		pending = false
		level.player.state_machine.stop(false)
		level.player.face_direction(1.0)
		_start_player_state()
		return
	var trip := _transport_trip.duplicate()
	var area := (trip["area"] as WeakRef).get_ref() as BaseLevelArea
	var was_loaded := area.runtime_loaded
	level._load_area(area)
	var arrival := _arrival_data(area, trip["target_id"], trip["animate"])
	if arrival.is_empty():
		if not was_loaded:
			level._unload_area(area)
		cancel(true)
		return
	if _transport_state != null:
		_transport_state.commit_transfer()
	_disconnect_transport_state()
	input_locked = true
	if not level._commit_area_arrival(area, trip["target_id"], arrival, under_cover):
		cancel(false)
		return
	var arrival_state := arrival["state"] as PlayerTransportState
	if arrival_state != null:
		_transport_trip = trip
		_transport_trip["source"] = null
		_transport_exiting = true
		arrival_state.configure(
			arrival["position"], arrival["direction"], true, arrival["distance"]
		)
		_start_transport_state(arrival_state)
	else:
		pending = false
		_start_player_state()


func _disconnect_transport_state() -> void:
	# Invalidate queued notifications before another phase/request can begin.
	_transport_phase += 1
	_restore_player_draw_order()
	if is_instance_valid(_transport_state):
		if _transport_state.exited.is_connected(_restore_player_draw_order):
			_transport_state.exited.disconnect(_restore_player_draw_order)
		if (
			_transport_completion_callback.is_valid()
			and _transport_state.travel_finished.is_connected(_transport_completion_callback)
		):
			_transport_state.travel_finished.disconnect(_transport_completion_callback)
	_transport_state = null
	_transport_completion_callback = Callable()
	_transport_trip.clear()
	_transport_exiting = false


func cancel(resume_player: bool) -> void:
	var state := _transport_state
	_disconnect_transport_state()
	pending = false
	if state == null:
		return
	if resume_player:
		input_locked = true
	if is_instance_valid(level.player) and level.player.state_machine.current_state == state:
		level.player.state_machine.stop(false)
		if resume_player and not level.is_shutdown and not level.player.is_shutdown:
			_start_player_state()


func _restore_player_draw_order() -> void:
	if _players_draw_index < 0:
		return
	var original_index := _players_draw_index
	_players_draw_index = -1
	# Do not reorder siblings while a dying player/level exits the tree.
	if level.is_shutdown or not is_instance_valid(level.player) or level.player.is_shutdown:
		return
	if is_instance_valid(level.players) and level.players.get_parent() == level:
		level.move_child(level.players, mini(original_index, level.get_child_count() - 1))
