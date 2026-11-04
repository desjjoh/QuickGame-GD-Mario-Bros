extends PlayerTransportState
## A non-pipe presentation to exercise the shared coordinator.
var target_position: Vector2
var frames: int = 0
var original_position: Vector2
var original_mask: int
var committed: bool = false


func configure(
	at: Vector2, _direction: Vector2 = Vector2.DOWN, _emerging: bool = false, _distance: float = 0.0
) -> void:
	target_position = at


func enter() -> void:
	frames = 0
	committed = false
	original_position = get_player().body.global_position
	original_mask = get_player().body.collision_mask
	get_player().body.collision_mask = 0


func process_physics(_delta: float) -> BaseState:
	frames += 1
	get_player().body.global_position = target_position
	if frames == 3:
		travel_finished.emit()
	return null


func commit_transfer() -> void:
	committed = true


func exit() -> void:
	get_player().body.collision_mask = original_mask
	if not committed:
		get_player().body.global_position = original_position
