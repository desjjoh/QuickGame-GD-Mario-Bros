extends Node


class InputProbe:
	extends BaseState
	var events: int = 0

	func process_input(_event: InputEvent) -> BaseState:
		events += 1
		return null


func _ready() -> void:
	var baseline := ControllerHandler.input_received.get_connections().size()
	var entity := load("res://scenes/entities/base/base_entity.tscn").instantiate() as BaseEntity
	var probe := InputProbe.new()
	entity.get_node("StateMachine").add_child(probe)
	entity.get_node("StateMachine").initial_state = probe
	add_child(entity)
	assert(not entity.controller_input_enabled)
	assert(not ControllerHandler.input_received.is_connected(entity.state_machine.process_input))
	var event := InputEventKey.new()
	ControllerHandler.input_received.emit(event)
	assert(probe.events == 0)
	entity.controller_input_enabled = true
	entity.controller_input_enabled = true
	assert(ControllerHandler.input_received.get_connections().size() == baseline + 1)
	ControllerHandler.input_received.emit(event)
	assert(probe.events == 1)
	entity.controller_input_enabled = false
	ControllerHandler.input_received.emit(event)
	assert(
		probe.events == 1 and ControllerHandler.input_received.get_connections().size() == baseline
	)
	entity.controller_input_enabled = true
	entity.set_gameplay_suspended(true)
	ControllerHandler.input_received.emit(event)
	assert(probe.events == 1 and not entity.can_read_controller_input())
	assert(ControllerHandler.input_received.get_connections().size() == baseline)
	entity.controller_input_enabled = false
	entity.set_gameplay_suspended(false)
	assert(ControllerHandler.input_received.get_connections().size() == baseline)
	entity.controller_input_enabled = true
	entity.set_gameplay_suspended(true)
	entity.set_gameplay_suspended(false)
	entity.set_gameplay_suspended(false)
	ControllerHandler.input_received.emit(event)
	assert(
		(
			probe.events == 2
			and ControllerHandler.input_received.get_connections().size() == baseline + 1
		)
	)
	entity.shutdown()
	entity.controller_input_enabled = false
	entity.controller_input_enabled = true
	ControllerHandler.input_received.emit(event)
	assert(
		probe.events == 2 and ControllerHandler.input_received.get_connections().size() == baseline
	)
	entity.free()
	# Placed blocks do not subscribe, even though their state machines exist.
	var blocks: Array[BaseEntity] = []
	for path in [
		"res://scenes/entities/blocks/brick/brick_block.tscn",
		"res://scenes/entities/blocks/question/question_block.tscn"
	]:
		var block := load(path).instantiate() as BaseEntity
		add_child(block)
		blocks.append(block)
		assert(not block.controller_input_enabled and not block.can_read_controller_input())
	assert(ControllerHandler.input_received.get_connections().size() == baseline)
	var mario := load("res://scenes/player/mario (small)/mario.tscn").instantiate() as BasePlayer
	add_child(mario)
	assert(mario.controller_input_enabled and mario.can_read_controller_input())
	assert(ControllerHandler.input_received.is_connected(mario.state_machine.process_input))
	mario.set_physics_process(false)
	ControllerHandler.input_right = 1.0
	ControllerHandler.input_secondary = true
	ControllerHandler.input_primary_just_pressed = true
	var player_state := mario.state_machine.current_state as PlayerState
	assert(player_state.get_movement_axis() == Vector2.RIGHT)
	mario.controller_input_enabled = false
	assert(player_state.get_movement_axis() == Vector2.ZERO)
	player_state.prepare_horizontal_motion()
	assert(mario.motion_values.max_speed == mario.motion_values.base_max_speed)
	mario.controller_input_enabled = true
	mario.begin_death(false)
	mario.controller_input_enabled = false
	mario.controller_input_enabled = true
	assert(not mario.can_read_controller_input())
	assert(not ControllerHandler.input_received.is_connected(mario.state_machine.process_input))
	var pipe := load("res://scenes/entities/pipes/pipe_entrance.tscn").instantiate() as PipeEntrance
	add_child(pipe)
	assert(pipe.controller_input_enabled and pipe.can_read_controller_input())
	pipe.controller_input_enabled = false
	assert(not pipe.can_start_entry(mario))
	assert(not ControllerHandler.input_received.is_connected(pipe.state_machine.process_input))
	pipe.free()
	mario.free()
	for block in blocks:
		block.free()
	ControllerHandler.input_right = 0.0
	ControllerHandler.input_secondary = false
	ControllerHandler.input_primary_just_pressed = false
	await get_tree().process_frame
	assert(ControllerHandler.input_received.get_connections().size() == baseline)
	print(
		"PASS: default entity/block input opt-out, player/pipe opt-in, no duplicate subscriptions, live toggles, suspension/resume, polling gates and dead/shutdown cleanup."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
