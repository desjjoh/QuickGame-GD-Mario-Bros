class_name PipeOpening
extends Node
## Authoring for a stage that starts at a castle and continues through a pipe.

@export var intro_area: BaseLevelArea
@export var castle_cell: Vector2i
@export var entrance_id: StringName = &"intro_pipe"

const WALK_PROFILE := &"pipe_opening"
const WALK_SPEED := 45.0  # NES entrance cap of 12/16 px per tick at 60 Hz.

var _level: BaseLevel
var _player: BasePlayer
var _entrance: PipeEntrance


func resolve_spawn(content: LevelAreaContent) -> Marker2D:
	var castle := content.find_layout_entity(intro_area, &"castle", castle_cell) as CastleEntity
	return castle.doorway if castle != null else null


func begin(level: BaseLevel, player: BasePlayer) -> void:
	var entrance := intro_area.find_transport_entity(entrance_id) as PipeEntrance
	if entrance == null or not entrance.sideways or not entrance.entrance_enabled:
		push_error("PipeOpening needs an enabled sideways pipe with its configured entrance ID.")
		return
	_level = level
	_player = player
	_entrance = entrance
	_player.opening_control_locked = true
	resume_walk()


func resume_walk() -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_entrance):
		return false
	_player.motion_values.set_modifier(WALK_PROFILE, {&"max_speed": WALK_SPEED}, 300)
	_player.scripted_motion_step = _advance_walk
	return true


func _advance_walk(delta: float) -> void:
	if _level.active_area != intro_area or not is_instance_valid(_entrance):
		cancel()
		return
	if not _level.can_transport():
		return
	_player.advance_scripted_walk(1.0, delta)
	if _entrance.can_start_transport(_player) and _level.transport(
		_player, _entrance.get_destination(), _entrance
	):
		_stop_walk()


func is_walking_into(player: BasePlayer, entrance: PipeEntrance) -> bool:
	return (
		is_instance_valid(player)
		and _player == player
		and _entrance == entrance
		and player.scripted_motion_step == _advance_walk
	)


func _stop_walk() -> void:
	if is_instance_valid(_player):
		_player.motion_values.remove_modifier(WALK_PROFILE)
		if _player.scripted_motion_step == _advance_walk:
			_player.scripted_motion_step = Callable()


func cancel() -> void:
	_stop_walk()
	if is_instance_valid(_player):
		_player.opening_control_locked = false
	_player = null
	_level = null
	_entrance = null
