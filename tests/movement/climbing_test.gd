extends Node

signal tick_finished
var attached: int = 0
var detached: int = 0
var watched_player: BasePlayer
var watch_climb: bool = false


func _physics_process(_delta: float) -> void:
	_check_climb_presentation()
	tick_finished.emit()


func _process(_delta: float) -> void:
	_check_climb_presentation()


func _check_climb_presentation() -> void:
	if watch_climb and is_instance_valid(watched_player):
		if (
			watched_player.state_machine.current_state != watched_player.climb_state
			or (
				watched_player.sprite.texture
				not in (watched_player as Mario).form_controller.current_form.climb
			)
		):
			watch_climb = false
			push_error(
				"Side-switch presentation left Climb at %s" % watched_player.body.global_position
			)
			get_tree().quit(1)


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await tick_finished


func _ready() -> void:
	# Rendered regression windows must not steal/drop focus during synthetic input.
	get_window().unfocusable = true
	process_physics_priority = 200
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	if "--super" in OS.get_cmdline_user_args():
		fixture.player_start_configuration = preload("res://assets/player/forms/super.tres")
	fixture.timer_enabled = false
	fixture.get_node("Players/PlayerSpawn").position = Vector2(40, 208)
	var ground := fixture.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(16):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	var layout := fixture.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(6, 2), 5, Vector2i.ZERO)
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	main.pipe_routes = []
	main.transport_points = []
	main.get_node("Camera2D").area_right = 256
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.stages.assign([packed])
	add_child(game)
	var level := GameHandler.current_level
	var player := level.player
	var pole := level.active_area.get_node("WorldObjects/flagpole_6_2") as BaseClimbable
	assert(pole != null and pole.get_node("Body") is StaticBody2D)
	assert(
		(
			not pole.controller_input_enabled
			and not pole.is_physics_processing()
			and not pole.is_processing()
		)
	)
	assert(
		(
			(
				(pole.get_node("Presentation/Tiles") as TileMapLayer).tile_set.get_source(2)
				as TileSetAtlasSource
			)
			. texture
			. resource_path
			. ends_with("overworld/tileset/block.tres")
		)
	)
	pole.set_activity_suspended(true)
	pole.set_activity_suspended(false)
	assert(not pole.is_physics_processing() and not pole.is_processing())
	pole.player_attached.connect(func(_player: BasePlayer): attached += 1)
	pole.player_detached.connect(func(_player: BasePlayer): detached += 1)
	# Contact alone grabs; no Up press and no completion/fanfare.
	player.face_direction(1.0)
	player.body.global_position = Vector2(111, 130)
	player.body.velocity = Vector2(120, -30)
	await ticks(5)
	assert(player.state_machine.current_state == player.climb_state)
	assert(attached == 1 and detached == 0 and not level.completion_in_progress)
	assert(player.body.velocity == Vector2.ZERO)
	assert(is_equal_approx(player.body.global_position.x, 113.0))
	var start_y := player.body.global_position.y
	await ticks(10)
	assert(is_equal_approx(player.body.global_position.y, start_y))
	assert(not player.animation_player.is_playing())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://.godot/validation/climbing-preview.png"
		)
	Input.action_press("ui_up")
	await ticks(16)
	Input.action_release("ui_up")
	assert(is_equal_approx(player.body.global_position.y, start_y - 14.0))
	assert(player.animation_player.current_animation == &"climb")
	assert(player.sprite.texture in (player as Mario).form_controller.current_form.climb)
	Input.action_press("ui_up")
	for frame in range(20):
		await ticks()
		if player.sprite.texture == (player as Mario).form_controller.current_form.climb[1]:
			break
	assert(player.sprite.texture == (player as Mario).form_controller.current_form.climb[1])
	Input.action_release("ui_up")
	await ticks()
	assert(player.sprite.texture == (player as Mario).form_controller.current_form.climb[0])
	# Down is faster; Run and Jump cannot replace the attached state.
	start_y = player.body.global_position.y
	Input.action_press("ui_down")
	Input.action_press("secondary")
	Input.action_press("primary")
	await ticks(8)
	Input.action_release("ui_down")
	Input.action_release("secondary")
	Input.action_release("primary")
	assert(is_equal_approx(player.body.global_position.y, start_y + 15.96875))
	assert(player.state_machine.current_state == player.climb_state)
	watched_player = player
	watch_climb = true
	player.state_machine.state_changed.connect(
		func(_previous: BaseState, next: BaseState):
			if watch_climb:
				assert(
					next == player.climb_state,
					(
						"Switching sides must not exit Climb at %s (axis %s)."
						% [player.body.global_position, ControllerHandler.get_axis()]
					)
				)
	)
	await ticks()
	var held_pose := player.sprite.texture
	Input.action_press("ui_right")
	await ticks()
	assert(player.sprite.flip_h and is_equal_approx(player.body.global_position.x, 127.0))
	assert(player.sprite.texture == held_pose, "A side switch must keep its climbing pose.")
	await ticks(30)
	assert(
		player.state_machine.current_state == player.climb_state,
		"Holding a switch is not a release."
	)
	Input.action_release("ui_right")
	await ticks()
	# With neutral horizontal input, the next inward switch is immediately ready.
	Input.action_press("ui_left")
	await ticks()
	assert(not player.sprite.flip_h and is_equal_approx(player.body.global_position.x, 113.0))
	await ticks(30)
	assert(player.state_machine.current_state == player.climb_state)
	Input.action_release("ui_left")
	# Opposite input without a neutral tick still respects the switch cooldown.
	Input.action_press("ui_right")
	await ticks()
	assert(player.sprite.flip_h)
	Input.action_release("ui_right")
	Input.action_press("ui_left")
	await ticks()
	assert(player.sprite.flip_h)
	await ticks(23)
	assert(not player.sprite.flip_h)
	Input.action_release("ui_left")
	await ticks()
	# Suspension preserves pose/position; the surface never gains callbacks.
	player.set_gameplay_suspended(true)
	start_y = player.body.global_position.y
	Input.action_press("ui_up")
	await ticks(10)
	assert(is_equal_approx(player.body.global_position.y, start_y))
	player.set_gameplay_suspended(false)
	await ticks(160)
	Input.action_release("ui_up")
	assert(is_equal_approx(player.body.global_position.y, pole.climb_top.global_position.y))
	# Exercise the same discrete switches at the top and bottom under render monitoring.
	for direction in ["ui_right", "ui_left"]:
		Input.action_press(direction)
		await ticks()
		Input.action_release(direction)
		await ticks()
	Input.action_press("ui_down")
	await ticks(90)
	Input.action_release("ui_down")
	assert(player.state_machine.current_state == player.climb_state and detached == 0)
	assert(player.climbing.get_surface() == pole)
	assert(absf(player.body.global_position.y - pole.climb_bottom.global_position.y) < 0.1)
	await ticks(5)
	assert(attached == 1 and detached == 0 and not player.animation_player.is_playing())
	for direction in ["ui_right", "ui_left"]:
		Input.action_press(direction)
		await ticks()
		Input.action_release(direction)
		await ticks()
	start_y = player.body.global_position.y
	Input.action_press("ui_up")
	await ticks(8)
	Input.action_release("ui_up")
	assert(
		absf(player.body.global_position.y - (start_y - 7.0)) < 0.1,
		"Climb from base: start=%s end=%s" % [start_y, player.body.global_position.y]
	)
	assert(player.state_machine.current_state == player.climb_state and attached == 1)
	watch_climb = false
	# A future ending controller, not the bottom bound, explicitly changes state.
	assert(player.state_machine.change_state(player.climb_state.move_state))
	assert(detached == 1 and player.climbing.get_surface() == null)
	await ticks(5)
	assert(attached == 1, "An explicit release must not immediately re-grab.")
	# A real terrain body supports Mario above the base and blocks its side.
	player.body.global_position = Vector2(120, 180)
	player.body.velocity = Vector2.ZERO
	await ticks(25)
	assert(
		player.body.is_on_floor() and absf(player.body.global_position.y - 192.0) < 0.1,
		(
			"Base landing: %s floor=%s state=%s"
			% [
				player.body.global_position,
				player.body.is_on_floor(),
				player.state_machine.current_state.name
			]
		)
	)
	# Leave detection, then return to re-arm contact.
	player.body.global_position = Vector2(40, 130)
	await ticks(4)
	player.body.global_position = Vector2(113, 130)
	await ticks(5)
	assert(attached == 2 and player.state_machine.current_state == player.climb_state)
	for direction in ["ui_left", "ui_right", "ui_left", "ui_right"]:
		Input.action_press(direction)
		await ticks(30)
		Input.action_release(direction)
		await ticks()
		assert(player.climbing.get_surface() == pole)
		assert(player.state_machine.current_state == player.climb_state)
		assert(player.sprite.texture == (player as Mario).form_controller.current_form.climb[0])
	# Removing the surface must safely return to normal falling.
	pole.queue_free()
	await ticks(3)
	assert(player.climbing.get_surface() == null)
	assert(player.state_machine.current_state != player.climb_state)
	# A fresh base surface exercises death and transport cleanup too.
	var pole_scene := load("res://scenes/entities/climbables/flagpole/flagpole.tscn") as PackedScene
	var extra := pole_scene.instantiate() as BaseClimbable
	extra.position = Vector2(96, 32)
	level.active_area.get_node("WorldObjects").add_child(extra)
	player.body.global_position = Vector2(113, 130)
	player.body.velocity = Vector2.ZERO
	await ticks(5)
	assert(player.state_machine.current_state == player.climb_state)
	assert(level.request_area_transfer(&"lower"))
	await ticks(4)
	assert(
		(
			player.climbing.get_surface() == null
			and player.state_machine.current_state != player.climb_state
		)
	)
	# Timeout/death must exit climbing before its presentation owns the body.
	var lower_pole := pole_scene.instantiate() as BaseClimbable
	lower_pole.global_position = Vector2(96, 32)
	level.active_area.get_node("WorldObjects").add_child(lower_pole)
	lower_pole.global_position = player.body.global_position + Vector2(-17, -90)
	player.body.velocity = Vector2.ZERO
	await ticks(player.arrival_control_ticks_remaining)
	assert(player.can_read_controller_input())
	# Climb checks run before the arrival countdown advances.
	await ticks()
	assert(player.state_machine.current_state == player.climb_state)
	level.death_sound = null
	assert(level.on_death(player, true))
	assert(
		(
			player.climbing.get_surface() == null
			and player.state_machine.current_state is MarioDeadState
		)
	)
	game.free()
	await ticks(3)
	print(
		"PASS: painted full flagpole/base collision, signal-only surface, automatic grab, reference speeds/side timer, climb frames, bounds retain attachment, suspension, explicit detach/removal/area cleanup; no completion."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
