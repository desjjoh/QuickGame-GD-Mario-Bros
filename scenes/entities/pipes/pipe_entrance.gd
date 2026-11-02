class_name PipeEntrance
extends BaseEntity
## One upward-facing, 2x2 entrance. Paint the left opening cell.

@export var destination_area_id: StringName = &"lower"
@export var destination_endpoint_id: StringName = &"arrival"
@export var alignment_tolerance: float = 4.0

var _level: BaseLevel
var _visuals: Node2D = null


func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevel:
		ancestor = ancestor.get_parent()
	_level = ancestor as BaseLevel
	# Player moves first; the level camera/clamp runs afterward.
	process_physics_priority = 50
	super()
	if _level != null:
		_visuals = $Visuals
		_visuals.reparent(_level.get_node("ForegroundObjects"), true)
		var remote := $VisualTransform as RemoteTransform2D
		remote.remote_path = remote.get_path_to(_visuals)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_shutdown or not is_instance_valid(_level) or _level.is_shutdown:
		return
	if not _level.can_enter_pipe():
		return
	if _level.active_area != get_parent().get_parent():
		return
	var player := _level.player
	if not is_instance_valid(player) or player.is_shutdown:
		return
	if ControllerHandler.input_down <= 0.5 or ControllerHandler.input_up > 0.5:
		return
	if not can_start_entry(player):
		return
	_level.request_pipe_entry(self)


func shutdown() -> void:
	if is_shutdown:
		return
	super()
	var remote := get_node_or_null("VisualTransform") as RemoteTransform2D
	if remote != null:
		remote.remote_path = NodePath()
	if is_instance_valid(_visuals):
		_visuals.queue_free()
	_visuals = null


func can_start_entry(player: BasePlayer) -> bool:
	if is_shutdown or not is_instance_valid(player) or player.is_shutdown:
		return false
	# Check each direction independently: opposing buttons must not cancel
	# into a neutral axis and accidentally allow pipe entry.
	if ControllerHandler.input_left > 0.0 or ControllerHandler.input_right > 0.0:
		return false
	var state := player.state_machine.current_state as PlayerState
	if state == null or not state.controls_enabled or not player.body.is_on_floor():
		return false
	var feet := to_local(player.body.global_position)
	return absf(feet.x - 16.0) <= alignment_tolerance and absf(feet.y) <= 1.0
