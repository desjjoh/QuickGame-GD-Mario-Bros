extends Node

func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func playing_count(level: BaseLevel) -> int:
	var count := 0
	for audio: AudioStreamPlayer in level.find_children("*","AudioStreamPlayer",true,false):
		if audio.playing:
			count += 1
	return count

func verify_track(audio: AudioStreamPlayer, theme: AreaTheme) -> void:
	assert(audio != null and audio.playing)
	assert(audio.stream != theme.music)
	assert((audio.stream as AudioStreamMP3).loop == theme.music_loop)
	assert(audio.volume_db == theme.music_volume_db)
	assert(audio.stream.get_length() > 1.0)
	var playback := audio.stream.instantiate_playback()
	playback.start(0.0)
	var amplitude := 0.0
	for sample in playback.mix_audio(1.0,44100):
		amplitude = maxf(amplitude,maxf(absf(sample.x),absf(sample.y)))
	assert(amplitude > 0.01, "The supplied soundtrack must decode to audible samples.")
	playback.stop()

func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var main := level.active_area
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	assert(main.is_active and not lower.is_active and not lower.runtime_loaded)
	verify_track(main._music_player,main.theme)
	assert(not (main.theme.music as AudioStreamMP3).loop, "Runtime looping must not modify the source/imported stream.")
	assert(playing_count(level) == 1)
	var first := main._music_player
	main.enter_area()
	main.music_enabled = true
	assert(main._music_player == first, "Repeated entry/enabling must not restart or duplicate music.")
	level.player.play_sound_effect(load("res://assets/sfx/smb_pipe.wav"))
	assert(first.playing, "Player sound effects must not interrupt area music.")
	assert(not level.transport(level.player,TransportDestination.create(&"lower",&"missing")))
	assert(main._music_player == first and first.playing)
	# Preloading a destination does not activate its soundtrack.
	level._load_area(lower)
	assert(lower.runtime_loaded and not lower.is_active and lower._music_player == null)
	assert(playing_count(level) == 1)
	level._unload_area(lower)
	assert(level.transport(level.player,TransportDestination.create(&"main",&"player_spawn")))
	await ticks(3)
	assert(main._music_player == first and first.playing, "Same-area transport must keep the current track.")
	var first_ref: WeakRef = weakref(first)
	var stopped_before_destination := [false]
	lower.child_entered_tree.connect(func(child: Node):
		if child is AudioStreamPlayer:
			var old_audio := first_ref.get_ref() as AudioStreamPlayer
			stopped_before_destination[0] = old_audio == null or not old_audio.playing)
	assert(level.transport(level.player,TransportDestination.create(&"lower",&"arrival")))
	await ticks(4)
	assert(not main.is_active and lower.is_active and not main.runtime_loaded)
	assert(stopped_before_destination[0], "Old music must stop before destination playback can start.")
	verify_track(lower._music_player,lower.theme)
	assert(not (lower.theme.music as AudioStreamMP3).loop)
	assert(playing_count(level) == 1)
	# Silent test area: theme artwork stays assigned, music is optional per area.
	lower.music_enabled = false
	assert(lower.is_active and lower.theme.music != null and lower._music_player == null)
	assert(playing_count(level) == 0)
	lower.music_enabled = true
	var lower_music := lower._music_player
	assert(lower_music.playing)
	lower.music_enabled = true
	assert(lower._music_player == lower_music)
	var silent_theme := lower.theme.duplicate() as AreaTheme
	silent_theme.music = null
	lower.theme = silent_theme
	assert(lower._music_player == null and playing_count(level) == 0)
	var custom_theme := load("res://assets/themes/underground.tres").duplicate() as AreaTheme
	custom_theme.music_loop = false
	custom_theme.music_volume_db = -6.0
	lower.theme = custom_theme
	verify_track(lower._music_player,custom_theme)
	assert(playing_count(level) == 1)
	# Entering a disabled destination remains silent, then returning starts Overworld.
	main.music_enabled = false
	assert(level.transport(level.player,TransportDestination.create(&"main",&"player_spawn")))
	await ticks(4)
	assert(main.is_active and main._music_player == null and not lower.is_active)
	assert(playing_count(level) == 0)
	main.music_enabled = true
	verify_track(main._music_player,main.theme)
	var old_audio: WeakRef = weakref(main._music_player)
	assert(GameHandler.load_level(load("res://scenes/levels/test_level.tscn")))
	assert(old_audio.get_ref() == null or not old_audio.get_ref().playing)
	level = GameHandler.current_level
	assert(playing_count(level) == 1)
	# Reentrant level replacement from transport notifications must clean music too.
	var old_level: WeakRef = weakref(level)
	var replaced := [false]
	var departing_audio: Array[WeakRef] = []
	var on_session := func(key: StringName, value: Variant):
		if replaced[0] or key != &"current_area_id" or value != &"lower":
			return
		replaced[0] = true
		var departing := old_level.get_ref() as BaseLevel
		assert(departing.active_area._music_player.playing)
		departing_audio.append(weakref(departing.active_area._music_player))
		assert(GameHandler.load_level(load("res://scenes/levels/test_level.tscn")))
	GameHandler.session_value_changed.connect(on_session)
	assert(level.transport(level.player,TransportDestination.create(&"lower",&"arrival")))
	await ticks(4)
	GameHandler.session_value_changed.disconnect(on_session)
	assert(replaced[0])
	assert(departing_audio[0].get_ref() == null or not departing_audio[0].get_ref().playing)
	level = GameHandler.current_level
	assert(level.active_area.area_id == &"main" and playing_count(level) == 1)
	level.shutdown()
	level.shutdown()
	assert(not level.active_area.is_active and playing_count(level) == 0)
	game.free()
	await ticks(6)
	# Tree removal is also a cleanup fallback, without a managing level.
	var detached := load("res://scenes/levels/areas/base_area.tscn").instantiate() as BaseLevelArea
	detached.theme = load("res://assets/themes/overworld.tres")
	add_child(detached)
	detached.enter_area()
	var detached_audio := detached._music_player
	assert(detached_audio.playing)
	remove_child(detached)
	assert(not detached.is_active and not detached_audio.playing)
	detached.free()
	await ticks(6)
	print("PASS: theme music decodes, starts only on entry, loops on runtime copies, respects per-area mute, survives SFX/same-area travel, switches without overlap and cleans up on exit/replacement/shutdown/removal.")
	get_tree().quit()
