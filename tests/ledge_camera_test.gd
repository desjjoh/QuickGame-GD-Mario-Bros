extends Node

signal step_finished
var pending: Callable
var failures: Array[String] = []


func _physics_process(_delta: float) -> void:
	if pending.is_valid():
		var callback := pending
		pending = Callable()
		callback.call()
		step_finished.emit()


func _ready() -> void:
	var factory: Node = load("res://tests/camera_follow_test.gd").new()
	var game: Node = factory.make_game()
	factory.free()
	add_child(game)
	var level := GameHandler.current_level
	var player := level.player
	player.set_physics_process(false)
	level.set_physics_process(false)
	ControllerHandler.set_physics_process(false)
	var camera := get_viewport().get_camera_2d() as LevelCamera
	var platform := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	shape.shape = rectangle
	platform.add_child(shape)
	level.add_child(platform)
	for width in [16.0, 32.0]:
		rectangle.size = Vector2(width, 16)
		platform.position = Vector2(512 + width / 2, 168)
		await get_tree().physics_frame
		for speed in [90.0, 150.0]:
			for direction in [-1.0, 1.0]:
				for phase in [0.25, 0.75, 1.25]:
					for penetration in [-1.5, 1.0, 3.0]:
						pending = func():
							player.state_machine.stop(false)
							player.air_movement.end(player.motion_values)
							player.body.global_position = Vector2(400, 120)
							player.body.velocity = Vector2.ZERO
							player.body.move_and_slide()  # Clear prior floor/ceiling flags.
							var edge: float = 512.0 if direction > 0 else 512.0 + width
							var start_x: float = (
								edge
								- player.collision_shape.position.x
								- direction * (5.5 + speed / 60.0 - phase)
							)
							player.body.global_position = Vector2(start_x, 160.0 + penetration)
							player.body.reset_physics_interpolation()
							player.body.velocity = Vector2(direction * speed, 180)
							player.run_action.running_history = false
							player.face_direction(direction)
							ControllerHandler.input_left = maxf(-direction, 0)
							ControllerHandler.input_right = maxf(direction, 0)
							ControllerHandler.input_secondary = speed > 90.0
							ControllerHandler.input_primary = false
							ControllerHandler.input_primary_just_pressed = false
							player.state_machine.change_state(
								player.state_machine.get_state(&"Jump")
							)
							# Ensure the full-speed scroll zone for rightward movement.
							camera.global_position.x = start_x - 72.0
							camera.reset_target(player.body)
							var before := player.body.global_position.x
							var camera_before := camera.global_position.x
							player.state_machine.process_physics(1.0 / 60.0)
							camera.follow_target(player.body)
							var displacement := player.body.global_position.x - before
							var expected := player.body.velocity.x / 60.0
							var label := (
								"width=%s speed=%s dir=%s phase=%s penetration=%s"
								% [width, speed, direction, phase, penetration]
							)
							var should_land: bool = penetration + 180.0 / 60.0 <= 4.0
							if (
								should_land
								and (
									absf(displacement - expected) > 0.1
									or not player.body.is_on_floor()
								)
							):
								(
									failures
									. append(
										(
											label
											+ (
												" landing lost/doubled horizontal step: %s expected %s floor=%s"
												% [
													displacement,
													expected,
													player.body.is_on_floor()
												]
											)
										)
									)
								)
							if (
								not should_land
								and (
									player.body.is_on_floor()
									or player.body.global_position.y < 160.0 + penetration
								)
							):
								failures.append(
									label + " must reject excessive post-motion penetration"
								)
							var camera_expected := displacement if direction > 0 else 0.0
							if (
								absf(camera.global_position.x - camera_before - camera_expected)
								> 0.1
							):
								failures.append(label + " camera step mismatch")
						await step_finished
	game.free()
	ControllerHandler.set_physics_process(true)
	if not failures.is_empty():
		push_error("Ledge camera failures:\n" + "\n".join(failures))
		get_tree().quit(1)
		return
	print(
		"PASS: 48 accepted jump-state ledge landings preserve one horizontal step; 24 over-depth contacts reject rescue; all 72 retain matching right-only camera motion."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
