class_name EntityStateMachine
extends Node
## One machine per entity. Only direct BaseState children are registered.

signal state_changed(previous_state: BaseState, new_state: BaseState)

@export var initial_state: BaseState

var current_state: BaseState
var entity: BaseEntity
var _states: Dictionary[StringName, BaseState] = {}
var _initialized: bool = false
var _transitioning: bool = false
var _shutdown: bool = false


func initialize(owner_entity: BaseEntity) -> bool:
	if _initialized:
		return entity == owner_entity
	if owner_entity == null:
		return false

	_states.clear()
	for child in get_children():
		if child is BaseState:
			_states[child.name] = child
	# Empty machines are valid for entities without state-driven behavior yet.
	if initial_state == null and not _states.is_empty():
		push_error("%s needs an initial state." % get_path())
		return false
	if initial_state != null and not _states.values().has(initial_state):
		push_error("Initial state must be a direct child of this state machine.")
		return false

	entity = owner_entity
	for state: BaseState in _states.values():
		state.entity = entity
		state.state_machine = self
		# States are driven manually, never by independent engine callbacks.
		state.process_mode = Node.PROCESS_MODE_DISABLED
	_initialized = true
	return true


func start() -> bool:
	if not _initialized or _shutdown:
		return false
	if current_state != null or initial_state == null:
		return true
	return change_state(initial_state)


func stop(play_exit_presentation: bool = true) -> void:
	if _transitioning or current_state == null:
		return
	_transitioning = true
	var previous := current_state
	current_state = null
	previous.deactivate(play_exit_presentation)
	_transitioning = false
	state_changed.emit(previous, null)


func shutdown() -> void:
	_shutdown = true
	# An enter/exit hook may request shutdown during a transition.
	# That transition completes the stop once its hook returns.
	if not _transitioning:
		stop(false)


func get_state(state_name: StringName) -> BaseState:
	return _states.get(state_name)


func change_state(next_state: BaseState) -> bool:
	if not _initialized or _shutdown or _transitioning or next_state == null:
		return false
	if not _states.values().has(next_state):
		push_error("Cannot transition to a state owned by another machine.")
		return false
	if next_state == current_state:
		return true

	_transitioning = true
	var previous := current_state
	if previous != null:
		previous.deactivate()
	if _shutdown:
		current_state = null
		_transitioning = false
		state_changed.emit(previous, null)
		return false
	current_state = next_state
	current_state.activate()
	_transitioning = false
	state_changed.emit(previous, current_state)
	if _shutdown:
		stop(false)
	return true


func update(delta: float) -> void:
	if current_state != null and current_state.frame_updates_enabled:
		_transition_if_requested(current_state.update(delta))


func process_physics(delta: float) -> void:
	if current_state != null and current_state.physics_updates_enabled:
		_transition_if_requested(current_state.process_physics(delta))


func process_input(event: InputEvent) -> void:
	if current_state != null and current_state.input_enabled:
		if current_state is PlayerState and not current_state.controls_enabled:
			return
		_transition_if_requested(current_state.process_input(event))


func on_animation_finished(animation: StringName) -> void:
	if current_state != null:
		_transition_if_requested(current_state.animation_finished(animation))


func _transition_if_requested(next_state: BaseState) -> void:
	if next_state != null:
		change_state(next_state)
