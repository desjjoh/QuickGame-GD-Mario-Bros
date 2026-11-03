extends Node


func endpoint(parent: Node, id: StringName, at: Vector2) -> AreaEndpoint:
	var marker := load("res://scenes/levels/areas/area_endpoint.tscn").instantiate() as AreaEndpoint
	marker.name = id
	marker.endpoint_id = id
	marker.position = at
	parent.add_child(marker)
	return marker


func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	preload("res://tests/fixtures/named_endpoints.gd").add_to(fixture)
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	var markers := main.get_node("Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(4,11),3,Vector2i.ZERO)
	markers.set_cell(Vector2i(8,11),3,Vector2i.ZERO)
	var route_a := PipeRoute.new()
	route_a.cell = Vector2i(4,11)
	route_a.destination_area_id = &"main"
	route_a.destination_endpoint_id = &"near_start"
	var route_b := PipeRoute.new()
	route_b.cell = Vector2i(8,11)
	route_b.destination_area_id = &"main"
	route_b.destination_endpoint_id = &"near_end"
	main.transport_points = []
	main.pipe_routes = [route_a,route_b]
	(main.get_node("Endpoints/near_end") as AreaEndpoint).exit_direction = AreaEndpoint.ExitDirection.RIGHT
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area,true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	assert(ResourceSaver.save(packed,"res://.godot/validation/pipe-routes-roundtrip.tscn") == OK)
	fixture.free()
	game.initial_level = ResourceLoader.load("res://.godot/validation/pipe-routes-roundtrip.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	add_child(game)
	var level := GameHandler.current_level
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	main = level.active_area
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	var pipe_a := main.get_node("WorldObjects/pipe_entrance_4_11") as PipeEntrance
	var pipe_b := main.get_node("WorldObjects/pipe_entrance_8_11") as PipeEntrance
	pipe_a.set_physics_process(false)
	pipe_b.set_physics_process(false)
	assert(pipe_a.destination_endpoint_id == &"near_start")
	assert(pipe_b.destination_endpoint_id == &"near_end")
	assert(main.pipe_routes.size() == 2)
	assert(not level.request_area_transfer(&"lower",&"missing"))
	var duplicate := endpoint(main.get_node("Endpoints"),&"near_start",Vector2(200,208))
	assert(not level.request_area_transfer(&"main",&"near_start"))
	duplicate.free()
	var duplicate_area := load("res://scenes/levels/areas/base_area.tscn").instantiate() as BaseLevelArea
	duplicate_area.area_id = &"lower"
	duplicate_area.get_node("Camera2D").enabled = false
	level.get_node("Areas").add_child(duplicate_area)
	assert(not level.request_area_transfer(&"lower"))
	duplicate_area.free()
	# Reject a target removed while a deferred transfer waits.
	var removed := endpoint(lower.get_node("Endpoints"),&"removed",Vector2(50,50))
	assert(level.request_area_transfer(&"lower",&"removed"))
	removed.free()
	await get_tree().process_frame
	assert(level.active_area == main)
	# Same area, different endpoint: camera must reveal the selected exit.
	GameHandler.set_session_value(&"coins",11)
	assert(level.request_area_transfer(pipe_b.destination_area_id,pipe_b.destination_endpoint_id))
	await get_tree().process_frame
	assert(level.active_endpoint == main.resolve_endpoint(&"near_end"))
	assert(level.active_endpoint.exit_direction == AreaEndpoint.ExitDirection.RIGHT)
	assert(level.player.body.global_position == main.resolve_endpoint(&"near_end").global_position)
	var camera := main.get_node("Camera2D") as LevelCamera
	assert(camera.global_position.x > 128)
	assert(absf(level.player.body.global_position.x-camera.global_position.x) < 128)
	var arrival_position := level.player.body.global_position
	level.clamp_player_to_camera()
	assert(level.player.body.global_position == arrival_position)
	assert(GameHandler.get_session_value(&"current_endpoint_id") == &"near_end")
	assert(GameHandler.get_session_value(&"coins") == 11)
	assert(not level.can_enter_pipe())
	ControllerHandler.input_down = 0
	level._physics_process(1.0/60.0)
	assert(level.can_enter_pipe())
	assert(level.request_area_transfer(pipe_a.destination_area_id,pipe_a.destination_endpoint_id))
	await get_tree().process_frame
	assert(level.active_endpoint == main.resolve_endpoint(&"near_start"))
	assert(camera.global_position.x == 128)
	assert(not level.request_area_transfer(&"main",&"near_start"))
	# Old callers still arrive at the inherited Arrival marker.
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(level.player.body.global_position == lower.get_node("Arrival").global_position)
	assert(GameHandler.get_session_value(&"current_endpoint_id") == &"arrival")
	assert(get_viewport().get_camera_2d() == lower.get_node("Camera2D"))
	game.free()
	print("PASS: per-cell route save/reload, named and legacy endpoints, same-area exits, duplicate/missing/stale rejection, camera repositioning and input reentry lock.")
	get_tree().quit()
