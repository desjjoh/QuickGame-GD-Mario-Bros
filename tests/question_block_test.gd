extends Node


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	var fixture := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	var layout := fixture.find_child("EntityLayout", true, false) as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(4, 9), 1, Vector2i.ZERO)
	layout.set_cell(Vector2i(6, 9), 1, Vector2i.ZERO)
	var fixture_scene := PackedScene.new()
	assert(fixture_scene.pack(fixture) == OK)
	fixture.free()
	game.initial_level = fixture_scene
	add_child(game)
	var level := GameHandler.current_level
	var block := level.world_objects.get_node("question_block_4_9") as BaseBlock
	var other := level.world_objects.get_node("question_block_6_9") as BaseBlock
	assert(block.body is StaticBody2D and block.state_machine.current_state == null)
	assert(block.global_position == Vector2(64, 144))
	var animation := block.animation_player.get_animation(&"active")
	assert(animation.loop_mode == Animation.LOOP_LINEAR and is_equal_approx(animation.length, 0.8))
	for sample in [[0.0, "question-block.png"], [0.39, "question-block.png"],
		[0.41, "question-block-2.png"], [0.55, "question-block-3.png"], [0.7, "question-block-2.png"]]:
		block.animation_player.seek(sample[0], true)
		assert(block.sprite.texture.resource_path.ends_with(sample[1]))
	block.animation_player.seek(0.79, true)
	block.animation_player.advance(0.03)
	assert(block.sprite.texture.resource_path.ends_with("question-block.png"))
	assert(other.animation_player != block.animation_player)
	for frame in range(10):
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(block.animation_player.current_animation_position > 0.03)
	level.shutdown()
	assert(not block.animation_player.is_playing() and other.is_shutdown)
	game.free()
	print("PASS: generated question blocks, palette phase timing, loop wrap, live playback, solid body, and shutdown.")
	get_tree().quit()
