class_name CastleFireworksStep
extends EndingStep
## Castle owns presentation; this adapter awards completed bursts and waits.

var castle: CastleEntity
var count := 0
var _started_frame := -1


static func count_for_time(time: int, timer_enabled: bool = true) -> int:
	var digit := time % 10
	return digit if timer_enabled and digit in [1, 3, 6] else 0


func _ready() -> void:
	process_physics_priority = 51
	set_physics_process(false)


func _begin(ticket: int) -> void:
	_disconnect_castle()
	if not is_instance_valid(castle) or castle.is_shutdown:
		cancel()
		return
	castle.firework_finished.connect(_on_burst)
	castle.begin_fireworks(count)
	if not castle.fireworks_active:
		complete(ticket)
	else:
		_started_frame = Engine.get_physics_frames()
		set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() <= _started_frame:
		return
	if not is_instance_valid(castle) or castle.is_shutdown:
		cancel()
		return
	var ticket := current_ticket
	if castle.advance_fireworks() and active and ticket == current_ticket:
		complete(ticket)


func _on_burst() -> void:
	if not active:
		return
	SoundHandler.play_reward(&"fireworks")
	GameHandler.add_score(500)


func _disconnect_castle() -> void:
	if is_instance_valid(castle):
		if castle.firework_finished.is_connected(_on_burst):
			castle.firework_finished.disconnect(_on_burst)
		castle.cancel_fireworks()


func complete(ticket: int) -> void:
	if not active or ticket != current_ticket:
		return
	set_physics_process(false)
	_disconnect_castle()
	super.complete(ticket)


func cancel() -> void:
	set_physics_process(false)
	_disconnect_castle()
	SoundHandler.stop_reward(&"fireworks")
	super.cancel()


func _exit_tree() -> void:
	cancel()
