extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func point(cell: Vector2i, id: StringName) -> TransportPlacement:
	var result := TransportPlacement.new()
	result.cell = cell
	result.target_id = id
	return result


func _ready() -> void:
	var game = load("res://tests/fixtures/silent_game.tscn").instantiate()
	var fixture = load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	var layer := main.get_node("Layouts/EntityLayout") as TileMapLayer
	layer.clear()
	layer.set_cell(Vector2i(6, 11), 3, Vector2i.ZERO)
	layer.set_cell(Vector2i(10, 11), 3, Vector2i.ZERO)
	var return_point := point(Vector2i(6, 11), &"stage_return")
	return_point.entrance_enabled = false
	var other_point := point(Vector2i(10, 11), &"other")
	main.transport_points = [return_point, other_point]
	main.pipe_routes = []
	var portal: BaseEntity = load("res://scenes/entities/base/base_entity.tscn").instantiate()
	portal.set_script(load("res://tests/fixtures/transport_entity.gd"))
	var portal_scene := PackedScene.new()
	assert(portal_scene.pack(portal) == OK)
	portal.free()
	fixture.entity_scenes = fixture.entity_scenes.duplicate()
	fixture.entity_scenes[&"pipe_entrance"] = portal_scene
	var character: BasePlayer = fixture.player_scene.instantiate()
	var state := load("res://tests/fixtures/transport_state.gd").new() as PlayerTransportState
	state.name = "TestTravel"
	state.controls_enabled = false
	state.input_enabled = false
	character.get_node("StateMachine").add_child(state)
	state.owner = character
	var character_scene := PackedScene.new()
	assert(character_scene.pack(character) == OK)
	character.free()
	fixture.player_scene = character_scene
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	assert(ResourceSaver.save(packed, "res://.godot/validation/transport-roundtrip.tscn") == OK)
	fixture.free()
	game.initial_level = ResourceLoader.load(
		"res://.godot/validation/transport-roundtrip.tscn",
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	main = level.active_area
	return_point = main.transport_points[0]
	other_point = main.transport_points[1]
	var player := level.player
	var target := main.find_transport_entity(&"stage_return")
	var source := main.find_transport_entity(&"other")
	assert(target != null and source != null)
	assert(not target is PipeEntrance)
	var arrivals: Array[Vector2] = []
	player.state_machine.state_changed.connect(
		func(_previous: BaseState, next: BaseState):
			if _previous == null and next == player.state_machine.initial_state:
				arrivals.append(player.body.global_position)
	)
	var destination := TransportDestination.create(&"main", &"stage_return")
	var origin := player.body.global_position
	assert(not level.transport(player, TransportDestination.create(&"missing", &"stage_return")))
	assert(not level.transport(player, TransportDestination.create(&"main", &"missing")))
	assert(not level.transport(player, TransportDestination.create(&"", &"stage_return")))
	assert(not level.transport(player, TransportDestination.create(&"main", &"")))
	var detached := TransportEntity.new()
	assert(not level.transport(player, destination, detached))
	detached.free()
	var foreign := BasePlayer.new()
	assert(not level.transport(foreign, destination))
	foreign.free()
	var duplicate := point(Vector2i(10, 11), &"stage_return")
	main.transport_points.append(duplicate)
	assert(not level.transport(player, destination))
	main.transport_points.pop_back()
	return_point.exit_enabled = false
	assert(not level.transport(player, destination))
	return_point.exit_enabled = true
	assert(player.body.global_position == origin)
	# The selected pipe/portal itself supplies arrival geometry, wherever it moves.
	target.position.x += 16
	var expected := target.exit_position()
	GameHandler.set_session_value(&"coins", 17)
	player.face_direction(-1.0)
	assert(level.transport(player, destination, source))
	assert(player.state_machine.current_state.name == &"TestTravel")
	assert(not level.transport(player, destination, source))
	await ticks(12)
	assert(level.active_target_id == &"stage_return" and level.active_endpoint == null)
	assert(
		arrivals.size() == 1 and arrivals[0] == expected,
		"Control must resume at %s; arrivals=%s" % [expected, arrivals]
	)
	assert(player.state_machine.current_state != player.pipe_enter_state)
	assert(player.state_machine.current_state != player.state_machine.get_state(&"TestTravel"))
	assert(not player.sprite.flip_h, "Completed transport must restore right-facing control.")
	assert(player.body.collision_mask != 0)
	assert(GameHandler.get_session_value(&"coins") == 17)
	await ticks(1)
	var other := TransportDestination.create(&"main", &"other")
	assert(
		not level.transport(player, other, target),
		"An exit-only entity must reject use as an entrance."
	)
	assert(level.transport(player, other))
	await ticks(3)
	assert(level.active_target_id == &"other")
	# Deletion between request and deferred handoff cannot teleport the player.
	player.set_physics_process(false)
	origin = player.body.global_position
	assert(level.transport(player, destination))
	target.free()
	await get_tree().process_frame
	assert(player.body.global_position == origin)
	assert(level.can_transport())
	# The removed target is remembered across unloading and rejected without loading it.
	assert(level.transport(player, TransportDestination.create(&"lower", &"arrival")))
	await get_tree().process_frame
	assert(level.active_area.area_id == &"lower" and not main.runtime_loaded)
	assert(not level.transport(player, destination))
	assert(not main.runtime_loaded)
	game.free()
	await ticks(6)
	print(
		"PASS: shared transport supports non-pipe presentations, explicit IDs, moved targets, exit-only permissions, duplicate/missing/stale rejection, saved resources and unloaded removed targets."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
