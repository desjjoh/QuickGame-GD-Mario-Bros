extends Node
signal stepped
var player: BasePlayer
var pending_step := false


func _physics_process(delta: float) -> void:
	if pending_step:
		pending_step = false
		if not get_tree().paused:
			player._physics_process(delta)
		stepped.emit()


func step() -> void:
	pending_step = true
	await stepped
	await get_tree().process_frame


func ticks(count: int = 2) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func exhaust_lock() -> void:
	assert(player.arrival_control_ticks_remaining == 17)
	var x := player.body.global_position.x
	var y := player.body.global_position.y
	for i in range(17):
		assert(not player.can_read_controller_input())
		await step()
		assert(player.arrival_control_ticks_remaining == 16 - i)
		assert(is_equal_approx(player.body.global_position.x, x))
	assert(player.can_read_controller_input())
	assert(player.body.global_position.y > y, "Falling continues during the control lock.")
	await step()
	assert(player.body.velocity.x > 0, "Held direction resumes on the eighteenth movement tick.")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	var game = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await ticks(3)
	var level := GameHandler.current_level
	player = level.player
	assert(player.arrival_control_ticks_remaining == 0 and player.can_read_controller_input())
	ControllerHandler.set_physics_process(false)
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 1
	ControllerHandler.input_down = 0
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = true
	ControllerHandler.input_secondary = true
	player.set_physics_process(false)
	level.set_physics_process(false)
	assert(not level.request_area_transfer(&"missing"))
	assert(player.arrival_control_ticks_remaining == 0)
	assert(level.request_area_transfer(&"lower"))
	await ticks()
	assert(level.active_area.area_id == &"lower")
	assert(player.arrival_control_ticks_remaining == 17)
	assert(not ControllerHandler.input_received.is_connected(player.state_machine.process_input))
	# Pause is outside player input gating, and cannot consume the countdown.
	assert(GameHandler.request_pause_toggle())
	await ticks(20)
	await step()
	assert(player.arrival_control_ticks_remaining == 17)
	assert(GameHandler.request_pause_toggle())
	await exhaust_lock()
	ControllerHandler.input_primary_just_pressed = false
	ControllerHandler.input_primary = false
	ControllerHandler.input_right = 0
	# Animated arrival holds inside the pipe before emergence, then releases controls immediately.
	assert(level.transport(player, TransportDestination.create(&"main", &"secret_exit")))
	await ticks()
	assert(level.area_transport.has_active_state())
	assert(player.arrival_control_ticks_remaining == 17)
	var hidden_position := player.body.global_position
	assert(GameHandler.request_pause_toggle())
	await ticks(20)
	await step()
	assert(player.body.global_position == hidden_position)
	assert(player.arrival_control_ticks_remaining == 17)
	assert(GameHandler.request_pause_toggle())
	for i in range(17):
		await step()
		assert(player.body.global_position == hidden_position)
		assert(player.arrival_control_ticks_remaining == 16 - i)
	assert(level.area_transport.has_active_state())
	for i in range(180):
		assert(player.arrival_control_ticks_remaining == 0)
		await step()
		if not level.area_transport.has_active_state():
			break
	assert(not level.area_transport.has_active_state())
	assert(player.arrival_control_ticks_remaining == 0 and player.can_read_controller_input())
	# A new direct area placement and a cancelled pipe exit use the same owner.
	assert(level.request_area_transfer(&"lower"))
	await ticks()
	assert(player.arrival_control_ticks_remaining == 17)
	assert(level.transport(player, TransportDestination.create(&"main", &"secret_exit")))
	await ticks()
	assert(level.area_transport.has_active_state() and player.arrival_control_ticks_remaining == 17)
	level.area_transport.cancel(true)
	assert(not level.area_transport.pending and player.arrival_control_ticks_remaining == 0)
	assert(player.can_read_controller_input())
	# Death restart constructs a fresh player with ordinary immediate controls.
	var old_player := player
	assert(GameHandler.restart_after_death(level, level._progress_key))
	player = GameHandler.current_level.player
	assert(player != old_player and player.arrival_control_ticks_remaining == 0)
	assert(player.can_read_controller_input())
	game.free()
	await ticks()
	print("arrival_control_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
