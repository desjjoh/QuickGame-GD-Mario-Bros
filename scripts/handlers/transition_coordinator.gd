class_name TransitionCoordinator
extends Node
## Global transaction lifecycle; the persistent Game supplies screen presentation.

signal started(id: int, kind: StringName)
signal covered(id: int)
signal loaded(id: int, success: bool)
signal finished(id: int, success: bool)
signal frame_advanced

@export var area_minimum_frames: int = 12
@export var level_minimum_frames: int = 147
var busy: bool = false
var phase: StringName = &"idle"
var elapsed_frames: int = 0
var phase_frames: int = 0
var _id: int = 0
var _presented: bool = false
var _executing: bool = false
var _kind: StringName = &"area"
var _replaced_level: bool = false
var _required: int = 1
var _card_required: int = 1
var _game: Node
var _view: Control
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
	GameHandler.level_changed.connect(_on_level_changed)

func attach_game(game: Node, view: Control) -> void:
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

func begin(owner: Node, operation: Callable, kind: StringName = &"area", completion: Callable = Callable(), validator: Callable = Callable()) -> int:
	if busy or not available() or not is_instance_valid(owner) or not operation.is_valid(): return 0
	if owner != _game and owner != GameHandler.current_level: return 0
	_id += 1
	var ticket := _id
	busy = true
	phase = &"covering"
	_kind = kind
	_replaced_level = false
	elapsed_frames = 0
	phase_frames = 0
	_presented = false
	_required = maxi(1, area_minimum_frames)
	_card_required = maxi(1, level_minimum_frames)
	_owner = weakref(owner)
	_operation = operation
	_callback = completion
	_validator = validator
	_controller_enabled = ControllerHandler.enabled
	ControllerHandler.enabled = false
	_container_visible = _game.get_node("LevelContainer").visible
	_game.get_node("LevelContainer").hide()
	_hud_visible = _hud.visible
	_hud.hide()
	_view.get_node("Card").hide()
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
	if _kind == &"level" and success:
		if not await _show_stage(ticket,&"card",true,_card_required): return
		if not await _show_stage(ticket,&"outro",false,_required): return
	if _validator.is_valid(): success = success and bool(_validator.call())
	_finish(success)

func _hold_frames(ticket: int, count: int) -> bool:
	while phase_frames < count:
		await frame_advanced
		if not _valid(ticket): return false
	return _valid(ticket)

func _show_stage(ticket: int, stage: StringName, show_card: bool, count: int) -> bool:
	phase = stage
	phase_frames = 0
	_presented = false
	_view.get_node("Card").visible = show_card
	_hud.visible = show_card and _hud_visible
	await _present_frame()
	if not _valid(ticket): return false
	_presented = true
	return await _hold_frames(ticket,count)

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
	if _executing and _kind == &"level" and not _replaced_level:
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
	if is_instance_valid(_view): _view.hide()
	if is_instance_valid(_hud): _hud.visible = _hud_visible
	ControllerHandler.enabled = _controller_enabled
	ControllerHandler.input_primary_just_pressed = false
	frame_advanced.emit() # Release cancelled minimum-frame waiters.
	if callback.is_valid(): callback.call(success)
	finished.emit(ticket,success)
