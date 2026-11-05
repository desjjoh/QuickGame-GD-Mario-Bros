extends Node

var game: Node
var player: BasePlayer
var phase: int = -2
var wall: StaticBody2D


func _ready() -> void:
	game = load("res://tests/fixtures/silent_game.tscn").instantiate()
	add_child(game)
	preload("res://tests/test_floor.gd").extend_floor(game)
	var level := GameHandler.current_level
	level.keep_player_on_screen = false
	level.set_physics_process(false)
	player = level.player
	player.set_physics_process(false)
	wall = StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2, 80)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(79, 168)
	add_child(wall)
	Input.action_press(ControllerHandler.left_action)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	assert(Engine.is_in_physics_frame())
	var step := phase
	phase += 1
	if step == 0:
		player.body.global_position = Vector2(72, 208)
		player.body.velocity = Vector2(0, 30)
		player.body.move_and_slide()
		assert(player.body.is_on_floor())
	elif step == 1:
		ControllerHandler.input_left = 1.0
		ControllerHandler.input_right = 0.0
		player.body.velocity.x = 120.0
		assert(player.state_machine.change_state(player.state_machine.get_state(&"Slide")))
		player.state_machine.process_physics(delta)
		assert(player.body.is_on_wall() and player.body.velocity.x == 0.0)
		assert(
			player.state_machine.current_state is MarioSlideState,
			"Retain the collision frame's skid pose."
		)
		assert(player.sprite.texture.resource_path.ends_with("mario-small-slide.png"))
	elif step == 2:
		player.state_machine.process_physics(delta)
		assert(player.state_machine.current_state is MarioMoveState)
		assert(player.body.velocity.x < 0.0, "Reverse away from the wall on the very next tick.")
		assert(not player.motion_values._modifiers.has(&"slide"))
	elif step in [3, 4]:
		var side := -1.0 if step == 3 else 1.0
		var level := GameHandler.current_level
		var camera := get_viewport().get_camera_2d() as LevelCamera
		camera.follow_enabled = false
		camera.global_position = Vector2(128, 120)
		camera.force_update_scroll()
		player.body.global_position = Vector2(7 if side < 0 else 249, 208)
		player.body.velocity = Vector2(0, 30)
		player.body.move_and_slide()
		player.body.velocity.x = side * 120.0
		ControllerHandler.input_left = maxf(side, 0.0)
		ControllerHandler.input_right = maxf(-side, 0.0)
		assert(player.state_machine.change_state(player.state_machine.get_state(&"Slide")))
		player.state_machine.process_physics(delta)
		level.keep_player_on_screen = true
		level.clamp_player_to_camera()
		assert(player.state_machine.current_state is MarioSlideState)
		assert(player.body.velocity.x * side > 0.0)
		assert(is_equal_approx(player.body.global_position.x, 7.0 if side < 0 else 249.0))
		level.keep_player_on_screen = false
	elif step == 5:
		Input.action_release(ControllerHandler.left_action)
		ControllerHandler.input_left = 0.0
		game.free()
		print(
			"PASS: wall stop/skid presentation, immediate reversal and retained edge skid momentum in both directions."
		)
		get_tree().quit()
