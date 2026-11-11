extends Node2D
## Owns the reveal, its signage, and the pipes for this area visit.

const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")

@export var pipe_occupant: PipeSpawn

var _area: BaseLevelArea
var _level: BaseLevel
var _revealed := false


func _enter_tree() -> void:
	_area = get_parent().get_parent() as BaseLevelArea
	_level = BaseLevel.containing(self)
	if _area == null:
		return
	for child in $Pipes.get_children():
		var pipe := child as WarpZonePipe
		if pipe != null:
			pipe.visual_theme = _area.theme


func _ready() -> void:
	DRAW_ORDER.apply($Presentation, DRAW_ORDER.BEHIND_WORLD)
	$Presentation.hide()
	# Reveal after camera follow and before area spawners run.
	process_physics_priority = 105
	# Area streaming captures the authored branch before attaching live spawners.
	_attach_occupants.call_deferred()


func _attach_occupants() -> void:
	if _revealed or _level == null or _level.is_shutdown:
		return
	for child in $Pipes.get_children():
		var pipe := child as WarpZonePipe
		if pipe != null:
			pipe.attach_pipe_spawn(pipe_occupant)


func _physics_process(_delta: float) -> void:
	if _area == null or _level == null or _level.active_area != _area or not _level.can_transport():
		return
	var camera_left := _area.get_activity_region(false).position.x + _area.activation_buffer
	if camera_left < $RevealMarker.global_position.x:
		return
	_revealed = true
	$Presentation.show()
	for child in $Pipes.get_children():
		var pipe := child as WarpZonePipe
		if pipe != null:
			pipe.reveal()
	set_physics_process(false)
