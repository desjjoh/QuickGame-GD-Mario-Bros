extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	for theme in ["overworld", "underground", "castle"]:
		var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
		var area := level.get_node("Areas/MainArea") as BaseLevelArea
		area.theme = load("res://assets/themes/%s.tres" % theme)
		var layout := area.get_node("Layouts/EntityLayout") as TileMapLayer
		layout.tile_set = area.theme.entity_markers
		layout.clear()
		layout.set_cell(Vector2i(4, 9), 12, Vector2i.ZERO)
		layout.set_cell(Vector2i(5, 9), 13, Vector2i.ZERO)
		layout.set_cell(Vector2i(6, 9), 12, Vector2i.ZERO)
		area.question_block_rewards[Vector2i(6, 9)] = load(
			"res://scenes/entities/powerups/one_up_mushroom.tscn"
		)
		add_child(level)
		var first := level.world_objects.get_node("reward_brick_4_9") as QuestionBlock
		var alternate := level.world_objects.get_node("reward_brick_alternate_5_9") as QuestionBlock
		var mushroom := level.world_objects.get_node("reward_brick_6_9") as QuestionBlock
		for block in [first, alternate]:
			assert(block.persist_progress)
			assert(not block.get_node("Presentation/PaletteAnimation").enabled)
		var texture := first.sprite.texture
		assert(
			(
				texture.resource_path
				== "res://assets/palettes/%s/interactibles/blocks/brick.tres" % theme
			)
		)
		assert(
			(
				alternate.sprite.texture.resource_path
				== "res://assets/palettes/%s/interactibles/blocks/brick-alternate.tres" % theme
			)
		)
		await ticks(26)
		assert(first.sprite.texture == texture and not first.animation_player.is_playing())
		var coins := GameHandler.player_status.coins
		var score := GameHandler.player_status.score
		for block in [first, alternate]:
			assert(block.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP)))
			assert(block.capture_area_state().state == &"Inactive")
			assert(not block.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP)))
		assert(GameHandler.player_status.coins == (coins + 2) % 100)
		assert(GameHandler.player_status.score == score + 400)
		assert(mushroom.power_up_scene != null)
		assert(mushroom.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP)))
		await ticks(30)
		assert(first.state_machine.current_state.name == &"Inactive")
		assert(first.sprite.texture.resource_path.contains("question-block-4"))
		assert(not first.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP)))
		var restored := (
			load("res://scenes/entities/blocks/question/reward_brick.tscn").instantiate()
			as QuestionBlock
		)
		restored.restore_area_state(first.capture_area_state())
		level.world_objects.add_child(restored)
		assert(restored.state_machine.current_state.name == &"Inactive")
		level.queue_free()
		await ticks(2)
	print("reward_brick_test: PASS")
	get_tree().quit()
