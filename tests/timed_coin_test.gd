extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func bonk(block: QuestionBlock) -> bool:
	return block.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP))


func _ready() -> void:
	var reward := BlockReward.new()
	reward.kind = BlockReward.Kind.TIMED_COINS
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	var area := fixture.get_node("Areas/MainArea") as BaseLevelArea
	var layout := area.get_node("Layouts/EntityLayout") as TileMapLayer
	layout.clear()
	area.question_block_rewards.clear()
	for index in range(5):
		var cell := Vector2i(4 + index, 9)
		layout.set_cell(cell, [1, 9, 12, 13, 1][index], Vector2i.ZERO)
		area.question_block_rewards[cell] = reward
	for child in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(child, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	assert(ResourceSaver.save(packed, "res://.godot/validation/timed-coin-fixture.tscn") == OK)
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.initial_level = ResourceLoader.load(
		"res://.godot/validation/timed-coin-fixture.tscn",
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	add_child(game)
	await ticks(3)
	var level: BaseLevel = GameHandler.current_level
	area = level.active_area
	var blocks: Array[QuestionBlock] = []
	for id in [
		"question_block_4_9",
		"hidden_question_block_5_9",
		"reward_brick_6_9",
		"reward_brick_alternate_7_9",
		"question_block_8_9"
	]:
		blocks.append(level.world_objects.get_node(id))
	GameHandler.set_coins(98)
	GameHandler.set_score(0)
	var lives := GameHandler.player_status.lives
	var bounce_textures: Array[Texture2D] = []
	for block in blocks.slice(0, 4):
		var texture: Texture2D = block.sprite.texture
		assert(bonk(block))
		assert(block.sprite.texture == texture)
		bounce_textures.append(texture)
		assert(block.reward_ticks_remaining == 231)
		assert(block.capture_area_state().state == &"Active")
		assert(not bonk(block))
		block.get_node("StateMachine/Bouncing").entered.emit()
	assert(GameHandler.player_status.coins == 2 and GameHandler.player_status.score == 800)
	assert(GameHandler.player_status.lives == lives + 1)
	assert(GameHandler.request_pause_toggle())
	await ticks(10)
	assert(blocks[0].reward_ticks_remaining == 231)
	assert(GameHandler.request_pause_toggle())
	await ticks(5)
	for index in range(4):
		assert(blocks[index].state_machine.current_state.name == &"Bouncing")
		assert(blocks[index].sprite.texture == bounce_textures[index])
	await ticks(25)
	for block in blocks.slice(0, 4):
		assert(block.reward_ticks_remaining == 201)
		assert(block.state_machine.current_state.name == &"Active")
	var sync := blocks[0].get_node("Presentation/PaletteAnimation") as SynchronizedAnimation
	assert(sync.enabled)
	var phase := sync.cycle.phase_at(GameHandler.animation_clock.tick_count)
	var expected: String = [
		"question-block.tres",
		"question-block-2.tres",
		"question-block-3.tres",
		"question-block-2.tres"
	][phase]
	assert(blocks[0].sprite.texture.resource_path.ends_with(expected))
	assert(blocks[1].body.collision_layer == 1)
	assert(blocks[1].sprite.texture.resource_path.contains("question-block.tres"))
	var revealed := (
		load("res://scenes/entities/blocks/question/hidden_question_block.tscn").instantiate()
		as HiddenQuestionBlock
	)
	revealed.configure_reward(reward)
	revealed.restore_area_state(blocks[1].capture_area_state())
	level.world_objects.add_child(revealed)
	assert(revealed.reward_started and revealed.reward_ticks_remaining == 201)
	assert(revealed.state_machine.current_state.name == &"Active")
	assert(revealed.sprite.texture.resource_path.contains("question-block.tres"))
	revealed.queue_free()
	assert(bonk(blocks[4]))
	assert(bonk(blocks[0]) and blocks[0].reward_ticks_remaining == 201)
	# Camera activity sleep must not extend the window.
	blocks[2].set_activity_suspended(true)
	await ticks(200)
	assert(blocks[0].reward_ticks_remaining == 1)
	assert(blocks[2].reward_ticks_remaining == 1)
	assert(blocks[4].reward_ticks_remaining == 31)
	await ticks(1)
	assert(blocks[0].reward_ticks_remaining == 0)
	assert(blocks[0].state_machine.current_state.name == &"Active")
	blocks[2].set_activity_suspended(false)
	var before := GameHandler.player_status.score
	for block in blocks.slice(0, 4):
		assert(bonk(block))
		assert(block.sprite.texture.resource_path.contains("question-block-4.tres"))
		assert(block.capture_area_state().state == &"Inactive")
		assert(not bonk(block))
	assert(GameHandler.player_status.score == before + 800)
	# Save while the final bounce is running; no reward can replay on return.
	var remaining := blocks[4].reward_ticks_remaining
	assert(level.request_area_transfer(&"lower"))
	await ticks(5)
	assert(level.active_area.area_id == &"lower")
	var parked: Dictionary = GameHandler.get_area_progress(level._progress_key, &"main")
	var parked_ticks: int = parked.entities["question_block_8_9"].state.reward_ticks_remaining
	await ticks(20)
	assert(level.request_area_transfer(&"main"))
	await ticks(5)
	var used := level.world_objects.get_node("reward_brick_6_9") as QuestionBlock
	assert(used.state_machine.current_state.name == &"Inactive" and not bonk(used))
	var last := level.world_objects.get_node("question_block_8_9") as QuestionBlock
	assert(last.reward_started and last.reward_ticks_remaining < remaining)
	assert(last.reward_ticks_remaining > 0, "Unloaded time must not exhaust the reward.")
	assert(last.reward_ticks_remaining >= parked_ticks - 5)
	before = GameHandler.player_status.score
	assert(bonk(last))
	await ticks(35)
	assert(last.reward_ticks_remaining == 0)
	assert(bonk(last))
	assert(GameHandler.player_status.score == before + 400)
	await ticks(30)
	assert(not bonk(last))
	# Existing progress-reset policy applies to timed state on level recreation.
	assert(GameHandler.load_level(game.initial_level))
	last = GameHandler.current_level.world_objects.get_node("question_block_8_9") as QuestionBlock
	assert(last.state_machine.current_state.name == &"Inactive")
	assert(GameHandler.load_level(game.initial_level, true))
	last = GameHandler.current_level.world_objects.get_node("question_block_8_9") as QuestionBlock
	assert(not last.reward_started and last.reward_ticks_remaining == 0)
	assert(bonk(last) and last.reward_ticks_remaining == 231)
	await ticks(230)
	assert(last.reward_ticks_remaining == 1)
	assert(bonk(last))
	await ticks(30)
	# Expiry during a non-final bounce cannot retroactively consume its last coin.
	assert(last.reward_ticks_remaining == 0)
	assert(last.state_machine.current_state.name == &"Active")
	assert(last.capture_area_state().reward_started)
	assert(bonk(last))
	assert(last.capture_area_state().state == &"Inactive")
	game.queue_free()
	await ticks(2)
	print("timed_coin_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
