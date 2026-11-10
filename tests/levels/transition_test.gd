extends Node

signal release_work
var operation_ran: bool = false

const Definition = preload("res://scripts/transitions/transition_definition.gd")
const Stage = preload("res://scripts/transitions/transition_stage.gd")


func wait_until_idle() -> void:
	while GameHandler.transitions.busy:
		await get_tree().process_frame


func wait_until_busy() -> void:
	# Pipe entry lasts 0.8 seconds; count timeout ticks independently of FPS.
	for frame in range(180):
		if GameHandler.transitions.busy:
			return
		await get_tree().physics_frame
	assert(false, "Transition did not begin.")


func slow_work() -> bool:
	await release_work
	operation_ran = true
	return true


func covered_operation(game: Node) -> bool:
	assert(not game.get_node("UI/HUD").visible)
	operation_ran = true
	return true


func _ready() -> void:
	var director: TransitionCoordinator = GameHandler.transitions
	var area_definition := director.get_definition(&"area")
	var level_definition := director.get_definition(&"level")
	assert(
		area_definition.minimum_frames == 12 and level_definition.stages[0].minimum_frames == 147
	)
	area_definition.minimum_frames = 4
	level_definition.minimum_frames = 4
	level_definition.stages[0].minimum_frames = 8
	level_definition.stages[1].minimum_frames = 4
	assert(
		(load("res://assets/transitions/level.tres") as Resource).stages[0].minimum_frames == 147
	)
	var original_clear := RenderingServer.get_default_clear_color()
	var prior_clear := Color(0.13, 0.17, 0.19)
	RenderingServer.set_default_clear_color(prior_clear)
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	var fixture := load("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	fixture.get_node("Players/PlayerSpawn").position = Vector2(112, 176)
	var markers := fixture.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(6, 11), 3, Vector2i.ZERO)
	fixture.get_node("Areas/MainArea").transport_points.clear()
	fixture.death_sound = null
	fixture.death_fallback_delay = 0.0
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.stages.assign([packed])
	add_child(game)
	var level: BaseLevel
	var view = game.get_node("UI/ScreenContainer/TransitionScreen")
	assert(not view.has_node("Cover"))
	assert(director.busy and view.visible and view.presentation == null)
	assert(GameHandler.current_level == null and not game.get_node("LevelContainer").visible)
	assert(not ControllerHandler.enabled)
	assert(not game.get_node("UI/HUD").is_visible_in_tree())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var expected_bg := Color8(
			roundi(prior_clear.r * 255), roundi(prior_clear.g * 255), roundi(prior_clear.b * 255)
		)
		assert(
			image.get_pixel(0, 0).is_equal_approx(expected_bg),
			"Existing background changed: %s expected %s" % [image.get_pixel(0, 0), expected_bg]
		)
		assert(image.get_pixel(24, 16).is_equal_approx(expected_bg))
		assert(image.save_png("res://.godot/validation/transition-quick.png") == OK)
	while director.phase != &"card":
		await get_tree().process_frame
	level = GameHandler.current_level
	assert(not level.players.visible and level.player.gameplay_suspended)
	assert(is_instance_valid(view.presentation) and game.get_node("UI/HUD").visible)
	assert(game.get_node("UI/HUD/TimeHeading").visible)
	assert(not game.get_node("UI/HUD/TimeValue").visible)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(
			(
				get_viewport().get_texture().get_image().save_png(
					"res://.godot/validation/transition-card.png"
				)
				== OK
			)
		)
	while director.phase != &"outro":
		await get_tree().process_frame
	assert(not game.get_node("UI/HUD").visible and view.presentation == null)
	await wait_until_idle()
	assert(director.elapsed_frames >= 8 and not view.visible and level.players.visible)
	assert(not level.player.gameplay_suspended and ControllerHandler.enabled)
	assert(game.get_node("UI/HUD/TimeValue").visible == GameHandler.timer_enabled)
	assert(RenderingServer.get_default_clear_color() == prior_clear)
	# Named definitions select arbitrary presentation scenes, HUD and timings.
	assert(director.begin(level, func(): return true, &"unknown") == 0)
	var custom := Definition.new()
	custom.id = &"test_transition"
	custom.minimum_frames = 3
	var stage := Stage.new()
	stage.phase = &"test_card"
	stage.minimum_frames = 3
	stage.show_hud = false
	stage.scene = load("res://tests/fixtures/transition_presentation.tscn")
	custom.stages.append(stage)
	assert(director.register_definition(custom))
	assert(not director.register_definition(custom))
	assert(not director.register_definition(Definition.new()))
	custom.minimum_frames = 999
	assert(director.get_definition(&"test_transition").minimum_frames == 3)
	assert(director.begin(level, func(): return true, &"test_transition") > 0)
	# A running transaction uses a snapshot, not subsequent definition edits.
	director.get_definition(&"test_transition").stages[0].scene = null
	while director.phase != &"test_card":
		await get_tree().process_frame
	assert(is_instance_valid(view.presentation) and view.presentation.name == &"TestPresentation")
	assert(not game.get_node("UI/HUD").visible)
	assert(RenderingServer.get_default_clear_color() == prior_clear)
	await wait_until_idle()
	assert(RenderingServer.get_default_clear_color() == prior_clear and view.presentation == null)
	# Presentation cancellation restores render/input state too.
	director.get_definition(&"test_transition").stages[0].scene = stage.scene
	assert(director.begin(level, func(): return true, &"test_transition") > 0)
	while director.phase != &"test_card":
		await get_tree().process_frame
	director.cancel()
	assert(RenderingServer.get_default_clear_color() == prior_clear and view.presentation == null)
	assert(ControllerHandler.enabled and level.players.visible)
	# Invalid presentation roots fail without leaving the game suspended.
	var invalid := Definition.new()
	invalid.id = &"invalid_presentation"
	invalid.minimum_frames = 1
	var invalid_stage := Stage.new()
	invalid_stage.scene = load("res://tests/fixtures/transition_invalid_root.tscn")
	invalid.stages.append(invalid_stage)
	assert(director.register_definition(invalid))
	var failure: Array[bool] = []
	assert(
		(
			director.begin(
				level,
				func(): return true,
				&"invalid_presentation",
				func(ok: bool): failure.append(ok)
			)
			> 0
		)
	)
	await wait_until_idle()
	assert(failure == [false] and ControllerHandler.enabled and not level.player.gameplay_suspended)
	assert(RenderingServer.get_default_clear_color() == prior_clear)
	# Scripted presentations may cancel during _ready without locked-node frees.
	var cancel_on_ready := Definition.new()
	cancel_on_ready.id = &"cancel_on_ready"
	cancel_on_ready.minimum_frames = 1
	var cancel_stage := Stage.new()
	cancel_stage.scene = load("res://tests/fixtures/transition_cancel_on_ready.tscn")
	cancel_on_ready.stages.append(cancel_stage)
	assert(director.register_definition(cancel_on_ready))
	assert(director.begin(level, func(): return true, &"cancel_on_ready") > 0)
	await wait_until_idle()
	assert(view.presentation == null and not view.visible and ControllerHandler.enabled)
	assert(RenderingServer.get_default_clear_color() == prior_clear)
	# A complete covered frame must precede operation execution.
	operation_ran = false
	assert(director.begin(level, covered_operation.bind(game)) > 0)
	assert(not operation_ran)
	assert(director.begin(level, func(): return true) == 0)
	await wait_until_idle()
	assert(operation_ran and director.elapsed_frames >= 4)
	# Minimum hold is not permission to reveal unfinished loading.
	operation_ran = false
	assert(director.begin(level, slow_work) > 0)
	while director.elapsed_frames < 6:
		await get_tree().process_frame
	assert(director.busy and not operation_ran)
	release_work.emit()
	await wait_until_idle()
	assert(operation_ran)
	# A cancelled async result cannot finish or disturb a newer transaction.
	assert(director.begin(level, slow_work) > 0)
	while director.phase != &"loading":
		await get_tree().process_frame
	director.cancel()
	assert(not director.busy and not view.visible and not level.transition_in_progress)
	assert(director.begin(level, func(): return true) > 0)
	release_work.emit()
	await wait_until_idle()
	assert(ControllerHandler.enabled and level.players.visible)
	var music := MusicHandler.get_node("BackgroundMusic") as AudioStreamPlayer
	assert(music.playing and music.stream == MusicHandler._loops[MusicHandler.Track.OVERWORLD])
	assert((music.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	# Pipe entry finishes before the cover; only then can the area change.
	var pipe := level.world_objects.get_node("pipe_entrance_6_11") as PipeEntrance
	pipe.set_physics_process(false)
	for frame in range(4):
		await get_tree().physics_frame
	Input.action_press(ControllerHandler.down_action)
	for frame in range(2):
		await get_tree().physics_frame
	assert(level.transport(level.player, pipe.get_destination(), pipe))
	Input.action_release(ControllerHandler.down_action)
	await wait_until_busy()
	assert(
		(
			level.transition_in_progress
			and not level.players.visible
			and not game.get_node("UI/HUD").visible
		)
	)
	assert(not music.playing)
	await wait_until_idle()
	assert(music.playing and music.stream == MusicHandler._loops[MusicHandler.Track.UNDERGROUND])
	assert(level.active_area.area_id == &"lower" and not level.area_transport.pending)
	assert(level.player.body.collision_mask != 0 and level.players.visible)
	assert(not level.player.gameplay_suspended)
	# Respawn has the same global card lifecycle after the death sound stage.
	assert(level.on_death(level.player))
	assert(not music.playing)
	await wait_until_busy()
	assert(view.presentation == null and not game.get_node("UI/HUD").visible)
	await wait_until_idle()
	assert(GameHandler.current_level != level)
	level = GameHandler.current_level
	assert(level.active_area.area_id == &"main" and level.player != null)
	assert(music.playing and music.stream == MusicHandler._loops[MusicHandler.Track.OVERWORLD])
	assert(director.elapsed_frames >= 8 and not level.transition_in_progress)
	var main_area := level.active_area
	assert(level.request_area_transfer(&"main", &"player_spawn"))
	await wait_until_busy()
	assert(not music.playing)
	await wait_until_idle()
	assert(level.active_area == main_area and level.active_target_id == &"player_spawn")
	assert(music.playing and music.stream == MusicHandler._loops[MusicHandler.Track.OVERWORLD])
	# Public level transition replaces under cover and unlocks the new player.
	assert(GameHandler.transition_to_level(game.stages[0]))
	await wait_until_idle()
	assert(GameHandler.current_level != level)
	level = GameHandler.current_level
	assert(not level.player.gameplay_suspended and level.players.visible)
	# Replacement permission belongs to the definition, not a hardcoded ID.
	var custom_load := Definition.new()
	custom_load.id = &"test_loading"
	custom_load.minimum_frames = 1
	custom_load.allow_level_replacement = true
	assert(director.register_definition(custom_load))
	assert(director.begin(level, GameHandler.load_level.bind(game.stages[0]), &"test_loading") > 0)
	await wait_until_idle()
	assert(GameHandler.current_level != level and ControllerHandler.enabled)
	level = GameHandler.current_level
	# External replacement cancels pending work before it can load anything.
	operation_ran = false
	assert(director.begin(level, covered_operation.bind(game)) > 0)
	assert(GameHandler.load_level(game.stages[0]))
	assert(not director.busy)
	for frame in range(3):
		await get_tree().process_frame
	assert(not operation_ran and ControllerHandler.enabled)
	assert(director.begin(GameHandler.current_level, func(): return true) > 0)
	game.free()
	await get_tree().process_frame
	assert(not director.busy and ControllerHandler.enabled)
	area_definition.minimum_frames = 12
	level_definition.minimum_frames = 12
	level_definition.stages[0].minimum_frames = 147
	level_definition.stages[1].minimum_frames = 12
	assert(RenderingServer.get_default_clear_color() == prior_clear)
	RenderingServer.set_default_clear_color(original_clear)
	print(
		"PASS: named definitions, arbitrary presentations, snapshots, unchanged background, no Cover node, rendered visibility, minimum frames, slow loading, startup/respawn cards, real pipe transfer, control/visibility restoration, overlap rejection and stale/cancelled transaction safety."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
