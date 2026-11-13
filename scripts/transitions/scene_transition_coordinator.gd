class_name SceneTransitionCoordinator
extends Node

const Definition = preload("res://scripts/transitions/transition_definition.gd")
const Stage = preload("res://scripts/transitions/transition_stage.gd")
## Runs a covered operation and timed presentations through a supplied view.

signal started(id: int, kind: StringName)
signal covered(id: int)
signal loaded(id: int, success: bool)
signal finished(id: int, success: bool)
signal frame_advanced

@export var definitions: Array[Definition] = []
var _definitions: Dictionary[StringName, Definition] = {}
var _definition: Definition
var busy: bool = false
var _finishing: bool = false
var phase: StringName = &"idle"
var elapsed_frames: int = 0
var phase_frames: int = 0
var _id: int = 0
var _presented: bool = false
var _executing: bool = false
var _required: int = 1
var _view: Node
var _owner: WeakRef
var _callback: Callable
var _operation: Callable
var _validator: Callable


func _ready() -> void:
	process_physics_priority = -80
	for definition in definitions:
		register_definition(definition)


func register_definition(definition: Definition) -> bool:
	if (
		busy
		or _finishing
		or definition == null
		or not definition.is_valid()
		or _definitions.has(definition.id)
	):
		return false
	# Never mutate shared .tres assets through runtime/test configuration.
	_definitions[definition.id] = definition.duplicate(true) as Definition
	return true


func get_definition(kind: StringName) -> Definition:
	return _definitions.get(kind)


func attach_view(view: Control) -> void:
	cancel()
	_view = view


func available() -> bool:
	return is_instance_valid(_view)


func begin(
	transition_owner: Node,
	operation: Callable,
	kind: StringName = &"area",
	completion: Callable = Callable(),
	validator: Callable = Callable()
) -> int:
	if (
		busy
		or _finishing
		or not available()
		or not is_instance_valid(transition_owner)
		or not operation.is_valid()
	):
		return 0
	if not _accepts_owner(transition_owner):
		return 0
	var definition := get_definition(kind)
	if definition == null or not definition.is_valid():
		return 0
	_definition = definition.duplicate(true) as Definition
	_id += 1
	var ticket := _id
	busy = true
	_before_cover()
	phase = &"covering"
	elapsed_frames = 0
	phase_frames = 0
	_presented = false
	_required = _definition.minimum_frames
	_owner = weakref(transition_owner)
	_operation = operation
	_callback = completion
	_validator = validator
	_prepare_cover()
	_view.clear_presentation()
	_view.show()
	_suspend_content()
	started.emit(ticket, kind)
	if busy and _id == ticket:
		_run.call_deferred(ticket)
	return ticket


func _valid(ticket: int) -> bool:
	return (
		busy
		and ticket == _id
		and available()
		and _owner != null
		and is_instance_valid(_owner.get_ref())
	)


func _present_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _run(ticket: int) -> void:
	await _present_frame()
	if not _valid(ticket):
		return
	_presented = true
	covered.emit(ticket)
	if not _valid(ticket):
		return
	phase = &"loading"
	_executing = true
	var operation := _operation
	var result: Variant = await operation.call()
	if not _valid(ticket):
		return
	_executing = false
	_suspend_content()
	loaded.emit(ticket, result == true)
	if not _valid(ticket):
		return
	# Submit destination/camera state while it is still covered.
	await _present_frame()
	if not _valid(ticket):
		return
	phase = &"holding"
	if not await _hold_frames(ticket, _required):
		return
	var success: bool = result == true
	if success:
		for stage in _definition.stages:
			if not await _show_stage(ticket, stage):
				return
	if _validator.is_valid():
		success = success and bool(_validator.call())
	_finish(success)


func _hold_frames(ticket: int, count: int) -> bool:
	while phase_frames < count:
		await frame_advanced
		if not _valid(ticket):
			return false
	return _valid(ticket)


func _show_stage(ticket: int, stage: Stage) -> bool:
	phase = stage.phase
	phase_frames = 0
	_presented = false
	_apply_stage(stage)
	if not _view.show_presentation(stage.scene):
		if _valid(ticket):
			_finish(false)
		return false
	if not _valid(ticket):
		return false
	await _present_frame()
	if not _valid(ticket):
		return false
	_presented = true
	if not await _hold_frames(ticket, stage.minimum_frames):
		return false
	if not stage.wait_for_presentation:
		return true
	while _valid(ticket):
		var presentation := _view.presentation as Control
		if (
			not is_instance_valid(presentation)
			or not presentation.has_method("is_presentation_complete")
		):
			_finish(false)
			return false
		var complete: bool = presentation.is_presentation_complete()
		if not _valid(ticket):
			return false
		if complete:
			return true
		if phase_frames >= maxi(stage.minimum_frames, stage.completion_timeout_frames):
			_finish(false)
			return false
		await frame_advanced
	return false


func _physics_process(_delta: float) -> void:
	if busy and (not available() or _owner == null or not is_instance_valid(_owner.get_ref())):
		cancel()
		return
	if busy and _presented:
		elapsed_frames += 1
		phase_frames += 1
		frame_advanced.emit()


func cancel() -> void:
	if busy:
		_finish(false)


func _finish(success: bool) -> void:
	var ticket := _id
	var callback := _callback
	_id += 1  # Invalidate pending render/physics/operation continuations.
	_finishing = true
	busy = false
	phase = &"idle"
	_executing = false
	_operation = Callable()
	_callback = Callable()
	_validator = Callable()
	_owner = null
	_restore_content()
	if is_instance_valid(_view):
		_view.clear_presentation()
		_view.hide()
	_definition = null
	_restore_host()
	frame_advanced.emit()  # Release cancelled minimum-frame waiters.
	_finishing = false
	if callback.is_valid():
		callback.call(success)
	finished.emit(ticket, success)


func _accepts_owner(_transition_owner: Node) -> bool:
	return true


func _before_cover() -> void:
	pass


func _prepare_cover() -> void:
	pass


func _suspend_content() -> void:
	pass


func _apply_stage(_stage: Stage) -> void:
	pass


func _restore_content() -> void:
	pass


func _restore_host() -> void:
	pass
