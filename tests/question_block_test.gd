extends Node

const BLOCK_COIN := preload("res://scenes/entities/blocks/question/block_coin.gd")
const ONE_UP := preload("res://scenes/entities/powerups/one_up_mushroom.tscn")


func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	var layout := fixture.find_child("EntityLayout", true, false) as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(4, 9), 1, Vector2i.ZERO)
	layout.set_cell(Vector2i(6, 9), 1, Vector2i.ZERO)
	var reward_cell := Vector2i(8, 9)
	layout.set_cell(reward_cell, 1, Vector2i.ZERO)
	var fixture_area := layout.get_parent().get_parent() as BaseLevelArea
	fixture_area.question_block_rewards[reward_cell] = ONE_UP
	var fixture_scene := PackedScene.new()
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	assert(fixture_scene.pack(fixture) == OK)
	fixture.free()
	game.initial_level = fixture_scene
	add_child(game)
	var level := GameHandler.current_level
	var block := level.world_objects.get_node("question_block_4_9") as BaseBlock
	var other := level.world_objects.get_node("question_block_6_9") as BaseBlock
	assert(block.body is StaticBody2D and block.state_machine.current_state.name == &"Active")
	assert(block.global_position == Vector2(64, 144))
	var events := {"entered": 0, "completed": 0}
	var bouncing: BaseState = block.state_machine.get_state(&"Bouncing")
	bouncing.entered.connect(func(): events["entered"] += 1)
	bouncing.bounce_completed.connect(func(): events["completed"] += 1)
	var phases: Array[StringName] = []
	block.state_machine.state_changed.connect(
		func(_previous: BaseState, current: BaseState):
			if current != null:
				phases.append(current.name)
	)
	var animation := block.animation_player.get_animation(&"active")
	assert(animation.loop_mode == Animation.LOOP_LINEAR and is_equal_approx(animation.length, 0.8))
	for sample in [
		[0.0, "question-block.tres"],
		[0.39, "question-block.tres"],
		[0.41, "question-block-2.tres"],
		[0.55, "question-block-3.tres"],
		[0.7, "question-block-2.tres"]
	]:
		block.animation_player.seek(sample[0], true)
		assert(block.sprite.texture.resource_path.ends_with(sample[1]))
	block.animation_player.seek(0.79, true)
	block.animation_player.advance(0.03)
	assert(block.sprite.texture.resource_path.ends_with("question-block.tres"))
	assert(other.animation_player != block.animation_player)
	for frame in range(10):
		await get_tree().physics_frame
		await get_tree().process_frame
	var phase := (
		(block.get_node("Presentation/PaletteAnimation").cycle as CosmeticAnimationCycle)
		. phase_at(GameHandler.animation_clock.tick_count)
	)
	assert(
		block.sprite.texture.resource_path.ends_with(
			[
				"question-block.tres",
				"question-block-2.tres",
				"question-block-3.tres",
				"question-block-2.tres"
			][phase]
		)
	)
	# Invalid attacks leave the block active; real upward player contact activates it.
	assert(not block.receive_hit(EntityHit.new(level.player, &"dash", Vector2.UP)))
	assert(not block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.DOWN)))
	level.player.body.global_position.x = 72.0
	for frame in range(5):
		await get_tree().physics_frame
		await get_tree().process_frame
	var starting_coins: int = GameHandler.get_session_value(&"coins")
	var starting_score: int = GameHandler.get_session_value(&"score")
	Input.action_press(ControllerHandler.primary_action)
	var activated := false
	var moved_sprite := false
	var original_body := block.body.global_transform
	var reward_effect: Sprite2D
	for frame in range(60):
		await get_tree().physics_frame
		await get_tree().process_frame
		activated = activated or block.state_machine.current_state.name == &"Inactive"
		moved_sprite = moved_sprite or block.sprite.position.y < 8.0
		assert(block.body.global_transform == original_body)
		if block.state_machine.current_state.name == &"Bouncing":
			assert(GameHandler.get_session_value(&"coins") == starting_coins + 1)
			assert(GameHandler.get_session_value(&"score") == starting_score + 200)
			for object in level.world_objects.get_children():
				if object is BLOCK_COIN:
					reward_effect = object
			assert(not block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	Input.action_release(ControllerHandler.primary_action)
	assert(activated and moved_sprite)
	assert(GameHandler.get_session_value(&"coins") == starting_coins + 1)
	assert(GameHandler.get_session_value(&"score") == starting_score + 200)
	assert(phases == [&"Bouncing", &"Inactive"])
	assert(events == {"entered": 1, "completed": 1})
	assert(block.sprite.texture.resource_path.ends_with("question-block-4.tres"))
	assert(block.sprite.position == Vector2(8, 8))
	assert(not block.animation_player.is_playing())
	assert(not block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	assert(other.state_machine.current_state.name == &"Active")
	assert(GameHandler.get_session_value(&"coins") == starting_coins + 1)
	assert(is_instance_valid(reward_effect))
	assert(reward_effect.texture == null and reward_effect.get_child_count() == 1)
	var popup := reward_effect.get_child(0) as Sprite2D
	assert(popup.visible and popup.region_rect == Rect2(0, 8, 16, 8))
	for frame in range(80):
		await get_tree().physics_frame
	assert(not is_instance_valid(reward_effect))
	var previous := ONE_UP.instantiate() as Mushroom
	assert(level.try_claim_spawn_slot(&"power_up", previous))
	level.world_objects.add_child(previous)
	var reward_block := level.world_objects.get_node("question_block_8_9") as QuestionBlock
	var lives_before := GameHandler.player_status.lives
	assert(reward_block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	var reveal_voice := SoundHandler.get_node("Square2Sfx") as AudioStreamPlayer
	assert(reveal_voice.playing and reveal_voice.stream == SoundHandler.get_sound(&"power_up_reveal"))
	assert(is_equal_approx(reveal_voice.stream.get_length(), 31.0 / 60.0))
	assert(previous.is_queued_for_deletion() and not previous.visible)
	var mushroom: Mushroom
	for object in level.world_objects.get_children():
		if object is Mushroom and object != previous:
			mushroom = object
	assert(mushroom != null and mushroom.position == reward_block.position)
	assert(not mushroom.sprite.visible)
	assert(not mushroom.pickup.monitoring and not level.has_spawn_capacity(&"power_up"))
	for frame in range(32):
		await get_tree().physics_frame
	assert(mushroom.position.y < reward_block.position.y and not mushroom.pickup.monitoring)
	assert(mushroom.sprite.region_enabled and mushroom.sprite.visible)
	var revealed_bottom := mushroom.sprite.global_position.y + mushroom.sprite.get_rect().end.y
	assert(is_equal_approx(revealed_bottom, reward_block.global_position.y))
	assert(is_zero_approx(mushroom.body.velocity.x))
	for frame in range(36):
		await get_tree().physics_frame
	assert(mushroom.position.y == reward_block.position.y - 16.0)
	assert(mushroom.pickup.monitoring and mushroom.body.velocity.x > 0.0)
	assert(not mushroom.sprite.region_enabled and mushroom.sprite.offset.y == 0.0)
	assert(GameHandler.player_status.lives == lives_before)
	assert(reward_block.capture_area_state() == {"state": &"Inactive"})
	# Shutdown during the entry reaction restores presentation and rejects hits.
	assert(other.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	assert(other.state_machine.current_state.name == &"Bouncing")
	var interrupted := {"completed": 0}
	other.state_machine.get_state(&"Bouncing").bounce_completed.connect(
		func(): interrupted["completed"] += 1
	)
	other.bounce.advance(1.0 / 60.0)
	assert(other.sprite.position.y < 8.0)
	level.shutdown()
	assert(not block.animation_player.is_playing() and other.is_shutdown)
	assert(other.sprite.position == Vector2(8, 8))
	assert(interrupted["completed"] == 0)
	assert(not other.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	game.free()
	print(
		"PASS: generated question blocks, palette phase timing, loop wrap, live playback, solid body, and shutdown."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
