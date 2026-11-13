extends Node

const LEVEL := preload("res://scenes/levels/worlds/world 1/1-4.tscn")
const GAME := preload("res://tests/fixtures/silent_game.tscn")
const FINISH := preload("res://tests/fixtures/finish_test.gd")
const BRIDGE_ROOM_LEFT := 2022.0

signal stepped


func _physics_process(_delta: float) -> void:
	stepped.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	var game := GAME.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.stages.assign([LEVEL])
	add_child(game)
	var level := GameHandler.current_level
	var ending := level.ending_presentation as CastleEndingPresentation
	var player := level.player as Mario
	player.set_physics_process(false)
	var area := level.active_area
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_position(area.global_position.x + 2210.0)
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
	area.update_camera_activity()
	var bridge := level.world_objects.get_node("CastleBridge") as CastleBridge
	var deck := bridge.get_node("Deck") as TileMapLayer
	var chain := bridge.get_node("Chain") as Sprite2D
	var axe := bridge.get_node("Axe") as CastleAxe
	assert(area.to_local(deck.global_position) == Vector2(2048, 160))
	assert(area.to_local(chain.global_position) == Vector2(2240, 144))
	assert(area.to_local(axe.global_position) == Vector2(2256, 128))
	assert(deck.get_used_cells().size() == 13)
	var touches: Array[BasePlayer] = []
	axe.touched.connect(func(traveler: BasePlayer) -> void: touches.append(traveler))
	var collapse_events: Array[int] = []
	bridge.collapse_finished.connect(
		func() -> void: collapse_events.append(deck.get_used_cells().size())
	)
	await stepped
	await stepped
	var boss := area.get_node(ending.boss_path) as Bowser
	boss.set_physics_process(false)
	boss.body.global_position.y = 128.0
	boss._feet_ticks = 18
	boss._vertical.position_fraction = 0
	var lift_spawner := area.get_node(ending.lift_spawner_path)
	assert(lift_spawner.get_child_count() > 1)

	var space := deck.get_world_2d().direct_space_state
	for column in range(13):
		var surface := deck.to_global(deck.map_to_local(Vector2i(column, 0))) - Vector2(0, 8)
		var ray := PhysicsRayQueryParameters2D.create(
			surface - Vector2(0, 2), surface + Vector2(0, 2)
		)
		var hit := space.intersect_ray(ray)
		assert(hit.get("collider") == deck, "Missing bridge collision at %s" % surface)
	var chain_ray := PhysicsRayQueryParameters2D.create(
		chain.global_position + Vector2(8, -2), chain.global_position + Vector2(8, 12)
	)
	assert(space.intersect_ray(chain_ray).is_empty())

	# Center-to-feet coordinates from the reference's side and right-foot trials.
	player.body.global_position = axe.global_position + Vector2(-5, 8)
	player.body.velocity = Vector2(60, 0)
	player.move_body()
	assert(touches.is_empty() and axe.visible)
	player.body.global_position = axe.global_position + Vector2(8, 8)
	player.body.velocity = Vector2(0, -120)
	player.move_body()
	assert(touches.is_empty() and axe.visible)
	camera.follow_position(area.global_position.x + 2252.0)
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
	var jump_state := player.state_machine.get_state(&"Jump")
	Input.action_press(ControllerHandler.secondary_action)
	player.run_action.apply(player.motion_values, true)
	assert(player.state_machine.change_state(jump_state))
	var contact_pose := player.sprite.texture
	player.body.global_position = axe.global_position + Vector2(-4, 0)
	player.body.velocity = Vector2(150, 120)
	var collapse_cues: Array[AudioStream] = []
	SoundHandler.reward_voice_changed.connect(
		func(occupied: bool) -> void:
			if occupied:
				collapse_cues.append(SoundHandler._square_two.stream)
	)
	ControllerHandler.input_right = 1.0
	player.state_machine.process_physics(1.0 / 60.0)
	ControllerHandler.input_right = 0.0
	assert(touches == [player] and not axe.visible)
	assert(player.sprite.texture == contact_pose, "Axe contact replaced Mario's jump pose.")
	assert(level.ending_in_progress and ending.phase == CastleEndingPresentation.Phase.HOLD)
	assert(camera.is_scroll_locked())
	assert(lift_spawner.is_queued_for_deletion() and not lift_spawner.visible)
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
	camera.follow_position(area.global_position.x + 2253.0)
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
	var held_position := player.body.global_position
	var shatter := ending.get_node("CollapseShatter") as AudioStreamPlayer
	assert(shatter.volume_db == 0.0 and shatter.pitch_scale == 1.0)
	player.set_physics_process(true)
	get_tree().paused = true
	await stepped
	await stepped
	assert(ending.phase == CastleEndingPresentation.Phase.HOLD)
	assert(player.body.global_position == held_position)
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
	get_tree().paused = false
	# Mesen records chain removal at tick 22 and deck columns right to left at 26–74.
	var deck_removal_ticks := [74, 70, 66, 62, 58, 54, 50, 46, 42, 38, 34, 30, 26]
	for tick in range(1, 75):
		await stepped
		assert(ending.phase == CastleEndingPresentation.Phase.HOLD)
		assert(player.body.global_position == held_position)
		assert(player.sprite.texture == contact_pose, "Mario changed pose on hold tick %s." % tick)
		assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
		var cue_count := maxi(0, floori(float(tick - 18) / 4.0) + 1)
		assert(collapse_cues.size() == cue_count)
		if tick >= 18 and (tick - 18) % 4 == 0:
			var cue := &"bowser_fall" if tick == 74 else &"fireworks"
			assert(collapse_cues.back() == SoundHandler.get_sound(cue))
			assert(shatter.playing and shatter.stream == SoundHandler.get_sound(&"brick_shatter"))
		assert(chain.visible == (tick < 22))
		for column in range(deck_removal_ticks.size()):
			var cell := Vector2i(column, 0)
			var removal_tick: int = deck_removal_ticks[column]
			assert(
				(deck.get_cell_source_id(cell) != -1) == (tick < removal_tick),
				"Unexpected deck state at column %s on tick %s" % [column, tick]
			)
			if tick == removal_tick + 1:
				var center := deck.to_global(deck.map_to_local(cell))
				var ray := PhysicsRayQueryParameters2D.create(
					center - Vector2(0, 10), center - Vector2(0, 6)
				)
				assert(space.intersect_ray(ray).is_empty())
		assert(collapse_events.is_empty() if tick < 74 else collapse_events == [0])
	bridge.collapse_next_piece()
	assert(collapse_events == [0])
	assert(boss.body.global_position.y == 128.0)
	for tick in range(75, 140):
		await stepped
		assert(ending.phase == CastleEndingPresentation.Phase.HOLD)
		assert(player.body.global_position == held_position)
		assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
		if tick == 100:
			var fall_y := boss.body.global_position.y
			get_tree().paused = true
			await stepped
			await stepped
			assert(boss.body.global_position.y == fall_y)
			assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT)
			get_tree().paused = false
		if tick == 137:
			assert(boss.body.global_position.y == 225.0)
		if tick == 138:
			assert(not is_instance_valid(boss) or boss.is_queued_for_deletion())
	await stepped
	assert(ending.phase == CastleEndingPresentation.Phase.WALK)
	assert(player.sprite.texture == contact_pose)
	assert(not camera.is_scroll_locked())
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT + 1.0)
	assert(ControllerHandler.input_secondary)
	assert(is_equal_approx(player.body.velocity.x, 90.0))
	assert(is_equal_approx(player.body.global_position.x - held_position.x, 1.5))
	await stepped
	assert(_camera_left(camera, area) == BRIDGE_ROOM_LEFT + 3.0)
	assert(axe.get_node("Body").collision_layer == 0)
	assert(deck.get_used_cells().is_empty() and not chain.visible)
	var final_center := deck.to_global(deck.map_to_local(Vector2i.ZERO))
	var final_ray := PhysicsRayQueryParameters2D.create(
		final_center - Vector2(0, 10), final_center - Vector2(0, 6)
	)
	assert(space.intersect_ray(final_ray).is_empty())
	axe.touch(player)
	assert(touches == [player])
	for tick in range(186):
		var before := player.body.global_position.x
		await stepped
		assert(player.body.global_position.x - before <= 1.501)
	Input.action_release(ControllerHandler.secondary_action)
	assert(ending.phase == CastleEndingPresentation.Phase.AT_RESCUE)
	assert(_camera_left(camera, area) == 2304.0)
	assert(area.to_local(player.body.global_position).x == 2436.0)
	assert(player.state_machine.current_state is MarioIdleState)
	level.cancel_ending()
	assert(not player.scripted_motion_step.is_valid())
	player.set_physics_process(false)
	level._unload_area(area)
	level._load_area(area)
	area.enter_area()
	level.initialize_actors(false)
	var reloaded_camera := area.get_node("Camera2D") as LevelCamera
	var reloaded_bridge := area.get_node("WorldObjects/CastleBridge") as CastleBridge
	var reloaded_axe := reloaded_bridge.axe
	assert(reloaded_axe.visible)
	assert(reloaded_bridge.get_node("Chain").visible)
	assert(reloaded_bridge.get_node("Deck").get_used_cells().size() == 13)
	player.body.global_position.x = area.global_position.x + 2252.0
	reloaded_camera.snap_to_arrival(player.body)
	assert(_camera_left(reloaded_camera, area) == BRIDGE_ROOM_LEFT)
	assert(player.state_machine.change_state(player.state_machine.get_state(&"Move")))
	assert(player.animation_player.is_playing())
	reloaded_axe.touch(player)
	assert(not reloaded_axe.visible)
	assert(not player.animation_player.is_playing())
	assert(ending.phase == CastleEndingPresentation.Phase.HOLD)
	reloaded_camera.follow_position(area.global_position.x + 2253.0)
	assert(_camera_left(reloaded_camera, area) == BRIDGE_ROOM_LEFT)
	level.cancel_ending()
	assert(player.animation_player.is_playing())
	game.free()
	print("castle_bridge_test: PASS")
	await FINISH.finish(get_tree())


func _camera_left(camera: LevelCamera, area: BaseLevelArea) -> float:
	var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	return camera.global_position.x - half_width - area.global_position.x
