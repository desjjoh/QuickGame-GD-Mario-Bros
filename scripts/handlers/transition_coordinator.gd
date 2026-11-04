class_name TransitionCoordinator
extends Node
const Definition = preload("res://scripts/transitions/transition_definition.gd")
const Stage = preload("res://scripts/transitions/transition_stage.gd")
## Global transaction lifecycle; the persistent Game supplies screen presentation.

signal started(id: int, kind: StringName)
signal covered(id: int)
signal loaded(id: int, success: bool)
signal finished(id: int, success: bool)
signal frame_advanced

@export var definitions: Array[Definition] = [
 preload("res://assets/transitions/area.tres"),
 preload("res://assets/transitions/level.tres"),
]
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
var _replaced_level: bool = false
var _required: int = 1
var _game: Node
var _view: Node
var _hud: Control
var _hud_visible: bool = true
var _owner: WeakRef
var _held_level: BaseLevel
var _callback: Callable
var _operation: Callable
var _validator: Callable
var _entities: Dictionary[int, Dictionary] = {}
var _players: Dictionary[int, Dictionary] = {}
var _container_visible: bool = true
var _controller_enabled: bool = true

func _ready() -> void:
	process_physics_priority = -80
	for definition in definitions:
		register_definition(definition)
	GameHandler.level_changed.connect(_on_level_changed)

func register_definition(definition: Definition) -> bool:
	if busy or _finishing or definition == null or not definition.is_valid() or _definitions.has(definition.id): return false
	# Never mutate shared .tres assets through runtime/test configuration.
	_definitions[definition.id] = definition.duplicate(true) as Definition
	return true

func get_definition(kind: StringName) -> Definition:
	return _definitions.get(kind)

func attach_game(game: Node, view: Node) -> void:
	cancel()
	_game = game
	_view = view
	_hud = game.get_node("UI/HUD") as Control

func detach_game(game: Node) -> void:
	if _game != game: return
	cancel()
	_game = null
	_view = null
	_hud = null

func available() -> bool:
	return is_instance_valid(_game) and GameHandler.current_game == _game and bool(_game.get("transitions_enabled")) and is_instance_valid(_view)

func begin(transition_owner: Node, operation: Callable, kind: StringName = &"area", completion: Callable = Callable(), validator: Callable = Callable()) -> int:
	if busy or _finishing or not available() or not is_instance_valid(transition_owner) or not operation.is_valid(): return 0
	if transition_owner != _game and transition_owner != GameHandler.current_level: return 0
	var definition := get_definition(kind)
	if definition == null or not definition.is_valid(): return 0
	_definition = definition.duplicate(true) as Definition
	_id += 1
	var ticket := _id
	busy = true
	phase = &"covering"
	_replaced_level = false
	elapsed_frames = 0
	phase_frames = 0
	_presented = false
	_required = _definition.minimum_frames
	_owner = weakref(transition_owner)
	_operation = operation
	_callback = completion
	_validator = validator
	_controller_enabled = ControllerHandler.enabled
	ControllerHandler.enabled = false
	_container_visible = _game.get_node("LevelContainer").visible
	_game.get_node("LevelContainer").hide()
	_hud_visible = _hud.visible
	_hud.hide()
	_view.clear_presentation()
	_view.show()
	_pause_level(GameHandler.current_level)
	started.emit(ticket,kind)
	if busy and _id == ticket: _run.call_deferred(ticket)
	return ticket

func _valid(ticket: int) -> bool:
	return busy and ticket == _id and available() and _owner != null and is_instance_valid(_owner.get_ref())

func _present_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func _run(ticket: int) -> void:
	await _present_frame()
	if not _valid(ticket): return
	_presented = true
	covered.emit(ticket)
	if not _valid(ticket): return
	phase = &"loading"
	_executing = true
	var operation := _operation
	var result: Variant = await operation.call()
	if not _valid(ticket): return
	_executing = false
	_pause_level(GameHandler.current_level)
	loaded.emit(ticket,result == true)
	if not _valid(ticket): return
	# Submit destination/camera state while it is still covered.
	await _present_frame()
	if not _valid(ticket): return
	phase = &"holding"
	if not await _hold_frames(ticket,_required): return
	var success: bool = result == true
	if success:
		for stage in _definition.stages:
			if not await _show_stage(ticket,stage): return
	if _validator.is_valid(): success = success and bool(_validator.call())
	_finish(success)

func _hold_frames(ticket: int, count: int) -> bool:
	while phase_frames < count:
		await frame_advanced
		if not _valid(ticket): return false
	return _valid(ticket)

func _show_stage(ticket: int, stage: Stage) -> bool:
	phase = stage.phase
	phase_frames = 0
	_presented = false
	_hud.visible = stage.show_hud and _hud_visible
	if not _view.show_presentation(stage.scene):
		if _valid(ticket): _finish(false)
		return false
	if not _valid(ticket): return false
	await _present_frame()
	if not _valid(ticket): return false
	_presented = true
	return await _hold_frames(ticket,stage.minimum_frames)

func _physics_process(_delta: float) -> void:
	if busy and (not available() or _owner == null or not is_instance_valid(_owner.get_ref())):
		cancel()
		return
	if busy and _presented:
		elapsed_frames += 1
		phase_frames += 1
		frame_advanced.emit()

func _pause_level(level: BaseLevel) -> void:
	if not is_instance_valid(level) or level.is_shutdown: return
	_held_level = level
	level.transition_in_progress = true
	if is_instance_valid(level.players):
		if not _players.has(level.players.get_instance_id()):
			_players[level.players.get_instance_id()] = {"node":weakref(level.players),"visible":level.players.visible}
		level.players.hide()
	for node in level.find_children("*","BaseEntity",true,false):
		var entity := node as BaseEntity
		if entity.is_shutdown: continue
		if not _entities.has(entity.get_instance_id()):
			_entities[entity.get_instance_id()] = {"node":weakref(entity),"suspended":entity.gameplay_suspended}
		entity.set_gameplay_suspended(true)

func _on_level_changed(level: BaseLevel) -> void:
	if not busy: return
	if _executing and _definition.allow_level_replacement and not _replaced_level:
		_replaced_level = true
		_owner = weakref(_game)
		_pause_level(level)
	elif level != _held_level: cancel()

func cancel_for_level(level: BaseLevel) -> void:
	if busy and not _executing and level == _held_level: cancel()

func cancel() -> void:
	if busy: _finish(false)

func _finish(success: bool) -> void:
	var ticket := _id
	var callback := _callback
	_id += 1 # Invalidate pending render/physics/operation continuations.
	_finishing = true
	busy = false
	phase = &"idle"
	_executing = false
	_operation = Callable()
	_callback = Callable()
	_validator = Callable()
	_owner = null
	if is_instance_valid(_held_level): _held_level.transition_in_progress = false
	_held_level = null
	for record: Dictionary in _entities.values():
		var entity := (record.node as WeakRef).get_ref() as BaseEntity
		if is_instance_valid(entity) and not entity.is_shutdown:
			entity.set_gameplay_suspended(record.suspended)
	_entities.clear()
	for record: Dictionary in _players.values():
		var players := (record.node as WeakRef).get_ref() as CanvasItem
		if is_instance_valid(players): players.visible = record.visible
	_players.clear()
	if is_instance_valid(_game): _game.get_node("LevelContainer").visible = _container_visible
	if is_instance_valid(_view):
		_view.clear_presentation()
		_view.hide()
	_definition = null
	if is_instance_valid(_hud): _hud.visible = _hud_visible
	ControllerHandler.enabled = _controller_enabled
	ControllerHandler.input_primary_just_pressed = false
	frame_advanced.emit() # Release cancelled minimum-frame waiters.
	_finishing = false
	if callback.is_valid(): callback.call(success)
	finished.emit(ticket,success)
