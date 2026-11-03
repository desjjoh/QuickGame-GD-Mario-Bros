extends Node


func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	var layout := fixture.find_child("EntityLayout", true, false) as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(4, 9), 1, Vector2i.ZERO)
	layout.set_cell(Vector2i(6, 9), 1, Vector2i.ZERO)
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
	block.state_machine.state_changed.connect(func(_previous: BaseState, current: BaseState):
		if current != null:
			phases.append(current.name))
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
	var phase := (block.get_node("Presentation/PaletteAnimation").cycle as CosmeticAnimationCycle).phase_at(GameHandler.animation_clock.tick_count)
	assert(block.sprite.texture.resource_path.ends_with(["question-block.png","question-block-2.png","question-block-3.png","question-block-2.png"][phase]))
	# Invalid attacks leave the block active; real upward player contact activates it.
	assert(not block.receive_hit(EntityHit.new(level.player, &"dash", Vector2.UP)))
	assert(not block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.DOWN)))
	level.player.body.global_position.x = 72.0
	for frame in range(5):
		await get_tree().physics_frame
		await get_tree().process_frame
	Input.action_press(ControllerHandler.primary_action)
	var activated := false
	var moved_sprite := false
	var original_body := block.body.global_transform
	for frame in range(60):
		await get_tree().physics_frame
		await get_tree().process_frame
		activated = activated or block.state_machine.current_state.name == &"Inactive"
		moved_sprite = moved_sprite or block.sprite.position.y < 8.0
		assert(block.body.global_transform == original_body)
		if block.state_machine.current_state.name == &"Bouncing":
			assert(not block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	Input.action_release(ControllerHandler.primary_action)
	assert(activated and moved_sprite)
	assert(phases == [&"Bouncing", &"Inactive"])
	assert(events == {"entered": 1, "completed": 1})
	assert(block.sprite.texture.resource_path.ends_with("question-block-4.png"))
	assert(block.sprite.position == Vector2(8, 8))
	assert(not block.animation_player.is_playing())
	assert(not block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	assert(other.state_machine.current_state.name == &"Active")
	# Shutdown during the entry reaction restores presentation and rejects hits.
	assert(other.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	assert(other.state_machine.current_state.name == &"Bouncing")
	var interrupted := {"completed": 0}
	other.state_machine.get_state(&"Bouncing").bounce_completed.connect(func(): interrupted["completed"] += 1)
	other.bounce.advance(1.0 / 60.0)
	assert(other.sprite.position.y < 8.0)
	level.shutdown()
	assert(not block.animation_player.is_playing() and other.is_shutdown)
	assert(other.sprite.position == Vector2(8, 8))
	assert(interrupted["completed"] == 0)
	assert(not other.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	game.free()
	print("PASS: generated question blocks, palette phase timing, loop wrap, live playback, solid body, and shutdown.")
	get_tree().quit()
