extends Node

const Probe = preload("res://tests/fixtures/movement_probe.gd")
signal stepped
var pending: Callable
var player: Probe
var takeoff_speeds: Array[float] = []
var failures: Array[String] = []


func _physics_process(_delta: float) -> void:
	if pending.is_valid():
		var callback := pending
		pending = Callable()
		callback.call()
		stepped.emit()


func step(callback: Callable) -> void:
	pending = callback
	await stepped


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	process_physics_priority = 200
	ControllerHandler.set_physics_process(false)
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_scene = load("res://tests/fixtures/movement_probe.tscn")
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(-16, 32):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	add_child(level)
	level.set_physics_process(false)
	level.active_area.set_physics_process(false)
	player = level.player as Probe
	player.set_physics_process(false)
	player.jump_action.jumped.connect(func(): takeoff_speeds.append(player.body.velocity.y))
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var cases: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/landing_rejump_reference.json")
	)
	for data: Dictionary in cases:
		await run_case(data)
	level.free()
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	ControllerHandler.input_primary_just_pressed = false
	ControllerHandler.input_secondary = false
	ControllerHandler.set_physics_process(true)
	if not failures.is_empty():
		push_error("Landing/re-jump reference failures:\n" + "\n".join(failures))
		get_tree().quit(1)
		return
	print("landing_rejump_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func run_case(data: Dictionary) -> void:
	var label := "%s travel=%s %s" % [data.form, data.travel, data.name]
	await step(
		func():
			player.state_machine.stop(false)
			player.form_controller.configure(
				player, load("res://assets/player/forms/" + data.form + ".tres")
			)
			player.body.global_position = Vector2(128, 160)
			player.body.velocity = Vector2.ZERO
			player.body.move_and_slide()  # Clear prior floor contact before seeding a descent.
			ControllerHandler.input_left = maxf(data.travel, 0)
			ControllerHandler.input_right = maxf(-data.travel, 0)
			ControllerHandler.input_down = 0
			ControllerHandler.input_primary = false
			ControllerHandler.input_primary_just_pressed = false
			ControllerHandler.input_secondary = true
			player.run_action.remaining_ticks = 0
			player.run_action.running_history = data.initial_speed >= 105
			player.run_action.apply(player.motion_values, false)
			player.motion_values.remove_modifier(&"ground_neutral")
			player.jump_action.active = true
			player.jump_action.falling_gravity = 1575
			player.body.global_position = Vector2(128, 206)
			player.body.velocity = Vector2(data.initial_speed * data.travel, 120)
			player.face_direction(data.travel)
			player.state_machine.change_state(player.get_node("StateMachine/Jump"))
			check(not player.body.is_on_floor(), label + " fixture must begin airborne")
	)
	takeoff_speeds.clear()
	var grounded_frames := 0
	var jump_start := -1
	var previous_jump := false
	var takeoff_step := 0
	var apex := 208.0
	for index in range(48):
		if player.body.is_on_floor():
			grounded_frames += 1
		if (
			not data.name.begins_with("contact")
			and jump_start < 0
			and player.body.is_on_floor()
			and grounded_frames > data.delay
		):
			jump_start = index
		var jump: bool = jump_start >= 0 and index - jump_start < data.hold
		if data.name == "contact_press":
			jump = index == 0
		elif data.name == "contact_hold":
			jump = index <= 2
		var just_pressed := jump and not previous_jump
		previous_jump = jump
		await step(
			func():
				ControllerHandler.input_primary = jump
				ControllerHandler.input_primary_just_pressed = just_pressed
				player.body_steps = 0
				player._physics_process(1.0 / 60.0)
				check(
					player.body_steps == 1, label + " must integrate once, tick " + str(index + 1)
				)
		)
		if index == 0:
			check(player.body.is_on_floor(), label + " first step must land")
		apex = minf(apex, player.body.global_position.y)
		if takeoff_step == 0 and not takeoff_speeds.is_empty():
			takeoff_step = index + 1
		if index < 4:
			check(
				absf(player.body.velocity.x - float(data.first_vx[index])) < 0.00001,
				label + " VX mismatch tick " + str(index + 1)
			)
	check(takeoff_step == int(data.takeoff_step), label + " takeoff tick mismatch")
	check(absf(apex - float(data.apex)) < 1.1, label + " reference apex mismatch: " + str(apex))
	if data.takeoff_step == 0:
		check(
			takeoff_speeds.is_empty(),
			label + " must not buffer/auto-repeat a landing-contact press"
		)
	else:
		check(takeoff_speeds.size() == 1, label + " must jump exactly once")
		if not takeoff_speeds.is_empty():
			check(
				takeoff_speeds[0] == -float(data.takeoff_speed),
				label + " wrong initial jump strength"
			)
