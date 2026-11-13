class_name TransitionCoordinator
extends "res://scripts/transitions/scene_transition_coordinator.gd"
## Supplies Mario's game, HUD, and gameplay suspension for scene transitions.

var _game: Node
var _hud: Control
var _hud_visible: bool = true
var _held_level: BaseLevel
var _replaced_level: bool = false
var _entities: Dictionary[int, Dictionary] = {}
var _players: Dictionary[int, Dictionary] = {}
var _container_visible: bool = true
var _controller_enabled: bool = true


func _init() -> void:
	definitions = [
		preload("res://assets/transitions/area.tres"),
		preload("res://assets/transitions/level.tres"),
		preload("res://assets/transitions/game_over.tres"),
		preload("res://assets/transitions/finish.tres"),
		preload("res://assets/transitions/time_up.tres"),
	]


func _ready() -> void:
	super()
	GameHandler.level_changed.connect(_on_level_changed)


func attach_game(game: Node, view: Control) -> void:
	attach_view(view)
	_game = game
	_hud = game.get_node("UI/HUD") as Control


func detach_game(game: Node) -> void:
	if _game != game:
		return
	attach_view(null)
	_game = null
	_hud = null


func available() -> bool:
	return (
		is_instance_valid(_game)
		and GameHandler.current_game == _game
		and bool(_game.get("transitions_enabled"))
		and is_instance_valid(_view)
	)


func _accepts_owner(transition_owner: Node) -> bool:
	return transition_owner == _game or transition_owner == GameHandler.current_level


func _before_cover() -> void:
	GameHandler.pause_controller.clear()


func _prepare_cover() -> void:
	_replaced_level = false
	_controller_enabled = ControllerHandler.enabled
	ControllerHandler.enabled = false
	_container_visible = _game.get_node("LevelContainer").visible
	_game.get_node("LevelContainer").hide()
	_hud_visible = _hud.visible
	_hud.hide()


func _suspend_content() -> void:
	_pause_level(GameHandler.current_level)


func _apply_stage(stage: Stage) -> void:
	_hud.visible = stage.show_hud and _hud_visible


func _pause_level(level: BaseLevel) -> void:
	if not is_instance_valid(level) or level.is_shutdown:
		return
	_held_level = level
	level.transition_in_progress = true
	if is_instance_valid(level.players):
		if not _players.has(level.players.get_instance_id()):
			_players[level.players.get_instance_id()] = {
				"node": weakref(level.players), "visible": level.players.visible
			}
		level.players.hide()
	for node in level.find_children("*", "BaseEntity", true, false):
		var entity := node as BaseEntity
		if entity.is_shutdown:
			continue
		if not _entities.has(entity.get_instance_id()):
			_entities[entity.get_instance_id()] = {
				"node": weakref(entity), "suspended": entity.gameplay_suspended
			}
		entity.set_gameplay_suspended(true)


func _on_level_changed(level: BaseLevel) -> void:
	if not busy:
		return
	if _executing and _definition.allow_level_replacement and not _replaced_level:
		_replaced_level = true
		_owner = weakref(_game)
		_pause_level(level)
	elif level != _held_level:
		cancel()
		# A replacement may have initialized while the old transaction was busy.
		if not busy and is_instance_valid(level) and GameHandler.current_level == level:
			level.transition_in_progress = false


func cancel_for_level(level: BaseLevel) -> void:
	if busy and not _executing and level == _held_level:
		cancel()


func _restore_content() -> void:
	if is_instance_valid(_held_level):
		_held_level.transition_in_progress = false
	_held_level = null
	for record: Dictionary in _entities.values():
		var entity := (record.node as WeakRef).get_ref() as BaseEntity
		if is_instance_valid(entity) and not entity.is_shutdown:
			entity.set_gameplay_suspended(record.suspended)
	_entities.clear()
	for record: Dictionary in _players.values():
		var players := (record.node as WeakRef).get_ref() as CanvasItem
		if is_instance_valid(players):
			players.visible = record.visible
	_players.clear()
	if is_instance_valid(_game):
		_game.get_node("LevelContainer").visible = _container_visible


func _restore_host() -> void:
	if is_instance_valid(_hud):
		_hud.visible = _hud_visible
	ControllerHandler.enabled = _controller_enabled
	ControllerHandler.input_primary_just_pressed = false
