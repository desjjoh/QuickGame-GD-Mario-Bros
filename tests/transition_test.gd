extends Node

signal release_work
var operation_ran: bool = false

func wait_until_idle() -> void:
	while GameHandler.transitions.busy:
		await get_tree().process_frame

func wait_until_busy() -> void:
	# Pipe entry lasts 0.8 seconds; count timeout ticks independently of FPS.
	for frame in range(180):
		if GameHandler.transitions.busy: return
		await get_tree().physics_frame
	assert(false, "Transition did not begin.")

func slow_work() -> bool:
	await release_work
	operation_ran = true
	return true

func _ready() -> void:
	var director: TransitionCoordinator = GameHandler.transitions
	assert(director.area_minimum_frames == 12 and director.level_minimum_frames == 147)
	director.area_minimum_frames = 4
	director.level_minimum_frames = 8
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	var fixture := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	fixture.get_node("Players/PlayerSpawn").position = Vector2(112,176)
	var markers := fixture.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(6,11),3,Vector2i.ZERO)
	fixture.get_node("Areas/MainArea").transport_points.clear()
	fixture.death_sound = null
	fixture.death_fallback_delay = 0.0
	for area in fixture.get_node("Areas").get_children(): fixture.set_editable_instance(area,true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
	add_child(game)
	var level: BaseLevel
	var view := game.get_node("UI/ScreenContainer/TransitionScreen") as Control
	assert(director.busy and view.visible and not view.get_node("Card").visible)
	assert(GameHandler.current_level == null and not game.get_node("LevelContainer").visible)
	assert(not ControllerHandler.enabled)
	assert(not game.get_node("UI/HUD").is_visible_in_tree())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		assert(image.get_pixel(0,0) == Color.BLACK)
		assert(image.get_pixel(24,16) == Color.BLACK)
		assert(image.save_png("res://.godot/validation/transition-quick.png") == OK)
	while director.phase != &"card": await get_tree().process_frame
	level = GameHandler.current_level
	assert(not level.players.visible and level.player.gameplay_suspended)
	assert(view.get_node("Card").visible and game.get_node("UI/HUD").visible)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/validation/transition-card.png") == OK)
	while director.phase != &"outro": await get_tree().process_frame
	assert(not game.get_node("UI/HUD").visible and not view.get_node("Card").visible)
	await wait_until_idle()
	assert(director.elapsed_frames >= 8 and not view.visible and level.players.visible)
	assert(not level.player.gameplay_suspended and ControllerHandler.enabled)
	# A complete covered frame must precede operation execution.
	operation_ran = false
	assert(director.begin(level,func(): assert(not game.get_node("UI/HUD").visible); operation_ran = true; return true) > 0)
	assert(not operation_ran)
	assert(director.begin(level,func(): return true) == 0)
	await wait_until_idle()
	assert(operation_ran and director.elapsed_frames >= 4)
	# Minimum hold is not permission to reveal unfinished loading.
	operation_ran = false
	assert(director.begin(level,slow_work) > 0)
	while director.elapsed_frames < 6: await get_tree().process_frame
	assert(director.busy and not operation_ran)
	release_work.emit()
	await wait_until_idle()
	assert(operation_ran)
	# A cancelled async result cannot finish or disturb a newer transaction.
	assert(director.begin(level,slow_work) > 0)
	while director.phase != &"loading": await get_tree().process_frame
	director.cancel()
	assert(not director.busy and not view.visible and not level.transition_in_progress)
	assert(director.begin(level,func(): return true) > 0)
	release_work.emit()
	await wait_until_idle()
	assert(ControllerHandler.enabled and level.players.visible)
	# Pipe entry finishes before the cover; only then can the area change.
	var pipe := level.world_objects.get_node("pipe_entrance_6_11") as PipeEntrance
	pipe.set_physics_process(false)
	for frame in range(4): await get_tree().physics_frame
	Input.action_press(ControllerHandler.down_action)
	for frame in range(2): await get_tree().physics_frame
	assert(level.request_pipe_entry(pipe))
	Input.action_release(ControllerHandler.down_action)
	await wait_until_busy()
	assert(level.transition_in_progress and not level.players.visible and not game.get_node("UI/HUD").visible)
	await wait_until_idle()
	assert(level.active_area.area_id == &"lower" and not level._transfer_pending)
	assert(level.player.body.collision_mask != 0 and level.players.visible)
	assert(not level.player.gameplay_suspended)
	# Respawn has the same global card lifecycle after the death sound stage.
	assert(level.on_death(level.player))
	await wait_until_busy()
	assert(not view.get_node("Card").visible and not game.get_node("UI/HUD").visible)
	await wait_until_idle()
	assert(GameHandler.current_level != level)
	level = GameHandler.current_level
	assert(level.active_area.area_id == &"main" and level.player != null)
	assert(director.elapsed_frames >= 8 and not level.transition_in_progress)
	# Public level transition replaces under cover and unlocks the new player.
	assert(GameHandler.transition_to_level(game.initial_level))
	await wait_until_idle()
	assert(GameHandler.current_level != level)
	level = GameHandler.current_level
	assert(not level.player.gameplay_suspended and level.players.visible)
	# External replacement cancels pending work before it can load anything.
	operation_ran = false
	assert(director.begin(level,func(): assert(not game.get_node("UI/HUD").visible); operation_ran = true; return true) > 0)
	assert(GameHandler.load_level(game.initial_level))
	assert(not director.busy)
	for frame in range(3): await get_tree().process_frame
	assert(not operation_ran and ControllerHandler.enabled)
	assert(director.begin(GameHandler.current_level,func(): return true) > 0)
	game.free()
	await get_tree().process_frame
	assert(not director.busy and ControllerHandler.enabled)
	director.area_minimum_frames = 12
	director.level_minimum_frames = 147
	print("PASS: rendered-cover sequencing, minimum frames, slow loading, startup/respawn cards, real pipe transfer, control/visibility restoration, overlap rejection and stale/cancelled transaction safety.")
	get_tree().quit()
