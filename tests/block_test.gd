extends Node


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	# Keep collision assertions independent of the user's painted test stage.
	var fixture := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	var fixture_layout := fixture.find_child("EntityLayout", true, false) as TileMapLayer
	fixture_layout.clear()
	for cell in [Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(11, 9)]:
		fixture_layout.set_cell(cell, 0, Vector2i.ZERO)
	var fixture_scene := PackedScene.new()
	assert(fixture_scene.pack(fixture) == OK)
	fixture.free()
	game.initial_level = fixture_scene
	add_child(game)
	var level := GameHandler.current_level
	assert(level.world_objects.get_child_count() == 4)
	assert(not level.entity_layout.visible and not level.entity_layout.collision_enabled)
	assert(level.entity_layout.tile_set.get_physics_layers_count() == 0)
	level.spawn_layout_entities()
	assert(level.world_objects.get_child_count() == 4, "Generation must not duplicate entities.")
	var block := level.get_node("WorldObjects/brick_4_9") as BaseBlock
	assert(block.body is StaticBody2D and block.sprite.texture != null)
	assert(block.state_machine.current_state.name == &"Active")
	var player := level.player
	player.body.global_position.x = 72.0
	for frame in range(5):
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(player.body.is_on_floor())
	Input.action_press(ControllerHandler.primary_action)
	var bumped := false
	var sprite_bounced := false
	var body_transform := block.body.global_transform
	for frame in range(60):
		await get_tree().physics_frame
		await get_tree().process_frame
		bumped = bumped or player.body.is_on_ceiling()
		sprite_bounced = sprite_bounced or block.sprite.position.y < 8.0
		assert(block.body.global_transform == body_transform)
		assert(player.body.global_position.y >= 173.8)
	Input.action_release(ControllerHandler.primary_action)
	assert(bumped and sprite_bounced and player.body.is_on_floor())
	assert(block.state_machine.current_state.name == &"Active")
	assert(block.sprite.position == Vector2(8, 8))
	assert(not block.receive_hit(EntityHit.new(player, &"dash", Vector2.UP)))
	assert(not block.receive_hit(EntityHit.new(player, &"bonk", Vector2.DOWN)))
	# A second real jump must bounce the same brick again.
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_press(ControllerHandler.primary_action)
	var bounced_again := false
	for frame in range(60):
		await get_tree().physics_frame
		await get_tree().process_frame
		bounced_again = bounced_again or block.sprite.position.y < 8.0
	Input.action_release(ControllerHandler.primary_action)
	assert(bounced_again and block.state_machine.current_state.name == &"Active")
	assert(block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, 10.0)))
	assert(not block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
	block.bounce.advance(1.0 / 60.0)
	assert(block.sprite.position.y < 8.0)
	assert(block.global_position == Vector2(64, 144))
	level.shutdown()
	assert(block.is_shutdown and block.sprite.position == Vector2(8, 8))
	game.free()
	# Layout generation also supports non-solid entities and a transformed level.
	var plain := load("res://scenes/levels/base/base_level.tscn").instantiate() as BaseLevel
	var layout := plain.find_child("EntityLayout", true, false) as TileMapLayer
	layout.tile_set = load("res://assets/tileset/entity_layout.tres")
	plain.position = Vector2(16, 32)
	layout.set_cell(Vector2i(-1, 2), 0, Vector2i.ZERO)
	plain.get_node("WorldObjects").position = Vector2(32, 16)
	plain.entity_scenes[&"brick"] = load("res://scenes/entities/base/base_entity.tscn")
	add_child(plain)
	var decoration := plain.world_objects.get_child(0) as BaseEntity
	assert(decoration.global_position == layout.to_global(Vector2(-16, 32)))
	assert(decoration.find_children("*", "CollisionObject2D", true, false).is_empty())
	plain.shutdown()
	assert(decoration.is_shutdown)
	plain.free()
	print("PASS: inherited brick entity, solid ceiling contact, landing, and level-owned shutdown.")
	get_tree().quit()
