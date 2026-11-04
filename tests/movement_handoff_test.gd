extends Node

const Probe = preload("res://tests/fixtures/movement_probe.gd")
signal state_tick_done
var pending_tick: Callable
var failures: Array[String] = []

func _physics_process(_delta: float) -> void:
	if pending_tick.is_valid():
		var callback := pending_tick
		pending_tick = Callable()
		callback.call()
		state_tick_done.emit()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _ready() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").clear()
	fixture.get_node("Areas/MainArea").transport_points.clear()
	var floor := fixture.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(64):
		floor.set_cell(Vector2i(x,13),0,Vector2i.ZERO)
	var character := fixture.player_scene.instantiate() as Mario
	var sprite := character.sprite
	var animator := character.animation_player
	var pipe_state := character.pipe_enter_state
	var controller_input := character.controller_input_enabled
	character.set_script(Probe)
	character.sprite = sprite
	character.animation_player = animator
	character.pipe_enter_state = pipe_state
	character.controller_input_enabled = controller_input
	var character_scene := PackedScene.new()
	assert(character_scene.pack(character) == OK)
	character.free()
	fixture.player_scene = character_scene
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area,true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var player := level.player as Probe
	player.set_physics_process(false)
	level.set_physics_process(false)
	ControllerHandler.set_physics_process(false)
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	var cases := [
		{"from":&"Idle", "to":&"Move", "speed":0.0, "axis":1.0, "ground":true, "accelerate":true},
		{"from":&"Idle", "to":&"Move", "speed":90.0, "axis":0.0, "ground":true},
		{"from":&"Move", "to":&"Slide", "speed":90.0, "axis":-1.0, "ground":true},
		{"from":&"Move", "to":&"Slide", "speed":150.0, "axis":-1.0, "ground":true},
		{"from":&"Slide", "to":&"Move", "speed":90.0, "axis":1.0, "ground":true},
		{"from":&"Idle", "to":&"Move", "speed":90.0, "axis":0.0, "ground":false},
		{"from":&"Slide", "to":&"Move", "speed":90.0, "axis":0.0, "ground":false},
		{"from":&"Jump", "to":&"Move", "speed":90.0, "axis":1.0, "ground":false, "land":true},
		{"from":&"Move", "to":&"Idle", "speed":0.0, "axis":0.0, "ground":true},
		{"from":&"Slide", "to":&"Idle", "speed":42.0, "axis":0.0, "ground":true},
		{"from":&"Idle", "to":&"Jump", "speed":90.0, "axis":1.0, "ground":true, "jump":true}
	]
	for direction in [-1.0,1.0]:
		for run_pressed in [false,true]:
			for trial: Dictionary in cases:
				pending_tick = func():
					player.state_machine.stop(false)
					ControllerHandler.input_primary = trial.get("jump",false)
					ControllerHandler.input_primary_just_pressed = trial.get("jump",false)
					ControllerHandler.input_secondary = run_pressed
					var axis: float = trial.axis * direction
					ControllerHandler.input_left = maxf(-axis,0.0)
					ControllerHandler.input_right = maxf(axis,0.0)
					player.body.global_position = Vector2(256,208 if trial.ground else (207 if trial.get("land",false) else 120))
					player.body.velocity = Vector2(0,60 if trial.ground else 0)
					player.move_body()
					player.body.velocity = Vector2(direction * trial.speed,60 if trial.get("land",false) else 0)
					# Each teleported case starts with independent run-timer history.
					player.run_action.remaining_ticks = 0
					player.run_action.apply(player.motion_values,run_pressed)
					player.face_direction(direction)
					player.body_steps = 0
					var origin := player.body.global_position
					assert(player.state_machine.change_state(player.state_machine.get_state(trial.from)))
					camera.position = Vector2(128,120)
					camera.reset_target(player.body)
					player.state_machine.process_physics(1.0/60.0)
					var displacement := player.body.global_position - origin
					var label := "%s->%s dir=%s run=%s" % [trial.from,trial.to,direction,run_pressed]
					check(player.body_steps == 1,label + " must integrate exactly once, got %s" % player.body_steps)
					check(player.state_machine.current_state.name == trial.to,label + " selected wrong state")
					check(absf(displacement.x - player.body.velocity.x / 60.0) < 0.05,label + " skipped or doubled horizontal displacement")
					if trial.get("accelerate",false):
						check(displacement.x * direction > 0.0,label + " must accelerate on the first input tick")
					if not trial.ground and not trial.get("land",false):
						check(displacement.y > 0.0,label + " must apply gravity on the falling handoff tick")
					camera.follow_target(player.body)
					check(absf(camera.position.x - 128.0 - maxf(displacement.x,0.0)) < 0.05,label + " camera must consume the same movement tick")
				await state_tick_done
	# Death/scene-change hooks may stop the player while the new state enters.
	pending_tick = func():
		player.state_machine.stop(false)
		ControllerHandler.input_primary_just_pressed = false
		ControllerHandler.input_primary = false
		ControllerHandler.input_left = 0
		ControllerHandler.input_right = 1
		player.body.global_position = Vector2(256,208)
		player.body.velocity = Vector2(0,60)
		player.move_body()
		assert(player.state_machine.change_state(player.state_machine.get_state(&"Idle")))
		player.body_steps = 0
		player.state_machine.state_changed.connect(func(_previous: BaseState, next: BaseState):
			if next != null and next.name == &"Move":
				player.shutdown())
		player.state_machine.process_physics(1.0/60.0)
		check(player.is_shutdown and player.state_machine.current_state == null,"Shutdown during handoff must remain terminal")
		check(player.body_steps == 0,"A handoff must not move a player shut down by its state-change observer")
		check(not ControllerHandler.input_received.is_connected(player.state_machine.process_input),"Shutdown must detach input")
	await state_tick_done
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	ControllerHandler.input_primary_just_pressed = false
	ControllerHandler.input_secondary = false
	ControllerHandler.set_physics_process(true)
	game.free()
	for frame in range(6):
		await get_tree().process_frame
	if not failures.is_empty():
		push_error("Movement handoff failures:\n" + "\n".join(failures))
		get_tree().quit(1)
		return
	print("PASS: 44 grounded/falling/skid/jump/landing handoffs integrate once and preserve horizontal displacement and camera motion in both directions with Run on/off.")
	get_tree().quit()
