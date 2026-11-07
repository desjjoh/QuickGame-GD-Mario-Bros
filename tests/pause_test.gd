extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func start_event(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)


func _ready() -> void:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await ticks(5)
	var level: BaseLevel = GameHandler.current_level
	assert(level.has_started)
	var pause: Node = GameHandler.pause_controller
	assert(pause.can_pause())
	var goomba: BaseEnemy = load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate()
	goomba.position = Vector2(180, 100)
	level.world_objects.add_child(goomba)
	var mushroom: PowerUp = (
		load("res://scenes/entities/powerups/one_up_mushroom.tscn").instantiate()
	)
	mushroom.position = Vector2(120, 140)
	mushroom.begin_emergence()
	level.world_objects.add_child(mushroom)
	var popup: Sprite2D = (
		load("res://scenes/components/presentation/score_popup.tscn").instantiate()
	)
	level.world_objects.add_child(popup)
	popup.show_score(200, Vector2(100, 100))
	var rise := popup.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_property(popup, "position:y", 76.0, 0.8)
	level.player.body.velocity = Vector2(30, -100)
	MusicHandler.play_area(level, MusicHandler.Track.OVERWORLD)
	SoundHandler.play_reward(&"extra_life")
	start_event(true)
	await ticks(2)
	assert(GameHandler.is_paused and get_tree().paused)
	var position := level.player.body.global_position
	var velocity := level.player.body.velocity
	var clock := GameHandler.animation_clock.tick_count
	var time := GameHandler.time_remaining
	var enemy_position := goomba.body.global_position
	var emergence_remaining := mushroom._emergence_remaining
	var popup_position := popup.position
	var music_position: float = MusicHandler._voice.get_playback_position()
	assert(MusicHandler._voice.stream_paused)
	assert(SoundHandler._square_two.stream_paused)
	assert(not SoundHandler._pause_voice.stream_paused)
	assert(SoundHandler._pause_voice.playing)
	assert(SoundHandler._pause_voice.volume_db == 0.0)
	assert(SoundHandler.get_sound(&"pause").get_length() == 0.7)
	start_event(true, true)
	await ticks(50)
	assert(GameHandler.is_paused)
	assert(not SoundHandler._pause_voice.playing)
	assert(level.player.body.global_position == position)
	assert(level.player.body.velocity == velocity)
	assert(GameHandler.animation_clock.tick_count == clock)
	assert(GameHandler.time_remaining == time)
	assert(goomba.body.global_position == enemy_position)
	assert(mushroom._emergence_remaining == emergence_remaining)
	assert(popup.position == popup_position)
	assert(absf(MusicHandler._voice.get_playback_position() - music_position) < 0.04)
	start_event(false)
	start_event(true)
	await ticks(3)
	assert(not GameHandler.is_paused and not get_tree().paused)
	assert(not ControllerHandler.input_primary_just_pressed)
	assert(not ControllerHandler.input_primary)
	assert(GameHandler.animation_clock.tick_count > clock)
	assert(level.player.body.global_position != position)
	assert(not MusicHandler._voice.stream_paused)
	assert(goomba.body.global_position != enemy_position)
	await ticks(5)
	assert(mushroom._emergence_remaining < emergence_remaining)
	assert(popup.position != popup_position)
	start_event(false)
	for property in [
		&"death_in_progress",
		&"transition_in_progress",
		&"completion_in_progress",
		&"ending_in_progress"
	]:
		level.set(property, true)
		assert(GameHandler.request_pause_toggle())
		assert(GameHandler.request_pause_toggle())
		level.set(property, false)
	level.area_transport.pending = true
	assert(pause.can_pause())
	level.area_transport.pending = false
	GameHandler._set_flow(GameHandler.GameFlow.COMPLETING)
	assert(GameHandler.request_pause_toggle())
	assert(GameHandler.request_pause_toggle())
	GameHandler.transitions.busy = true
	assert(not pause.can_pause())
	GameHandler.transitions.busy = false
	GameHandler._set_flow(GameHandler.GameFlow.TITLE)
	assert(not pause.can_pause())
	GameHandler._set_flow(GameHandler.GameFlow.PLAYING)
	assert(GameHandler.request_pause_toggle())
	game.transitions_enabled = true
	assert(GameHandler.transitions.begin(level, func(): return true) > 0)
	assert(not get_tree().paused and not GameHandler.is_paused)
	assert(not GameHandler.request_pause_toggle())
	GameHandler.transitions.cancel()
	assert(GameHandler.request_pause_toggle())
	level.shutdown()
	assert(not get_tree().paused and not GameHandler.is_paused)
	assert(not SoundHandler._pause_voice.playing)
	game.queue_free()
	await ticks(2)
	# Standalone F6 levels do not start the session timer, but remain pausable.
	var standalone := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	standalone.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(standalone)
	await ticks(2)
	assert(pause.can_pause())
	assert(GameHandler.request_pause_toggle())
	standalone.queue_free()
	await ticks(2)
	assert(not get_tree().paused)
	print("pause_test: PASS")
	get_tree().quit()
