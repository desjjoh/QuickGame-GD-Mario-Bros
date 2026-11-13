extends Node


func _ready() -> void:
	var nes_mix := AudioServer.get_bus_index(SoundHandler.NES_MIX_BUS)
	assert(nes_mix > 0 and AudioServer.get_bus_send(nes_mix) == &"Master")
	assert(AudioServer.get_bus_volume_db(nes_mix) == 0.0)
	assert(AudioServer.get_bus_effect_count(nes_mix) == 2)
	var high_pass := AudioServer.get_bus_effect(nes_mix, 0) as AudioEffectHighPassFilter
	var low_pass := AudioServer.get_bus_effect(nes_mix, 1) as AudioEffectLowPassFilter
	assert(high_pass != null and high_pass.cutoff_hz == 90.0)
	assert(low_pass != null and low_pass.cutoff_hz == 18000.0)
	assert(AudioServer.is_bus_effect_enabled(nes_mix, 0))
	assert(AudioServer.is_bus_effect_enabled(nes_mix, 1))
	assert(SoundHandler.get_node("PauseCue").bus == SoundHandler.NES_MIX_BUS)
	assert(MusicHandler.get_node("BackgroundMusic").bus == SoundHandler.NES_MIX_BUS)
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	add_child(game)
	var player := GameHandler.current_player
	player.set_gameplay_suspended(true)
	for cue in [&"jump_small", &"bump", &"flagpole", &"pipe"]:
		var generated := SoundHandler.get_sound(cue) as AudioStreamWAV
		assert(generated != null, "Missing generated player cue: %s" % cue)
		assert(
			(
				generated.data.size() > 2
				and generated.data.decode_s16(4410 if cue == &"pipe" else 0) != 0
			)
		)
	var streams := [
		"jump_small",
		"bump",
		"pipe",
		"flagpole",
		"res://assets/audio/music/stage_clear.wav",
	]
	var previous: AudioStreamPlayer
	for path: String in streams:
		var source := (
			load(path) as AudioStream
			if path.begins_with("res://")
			else SoundHandler.get_sound(path)
		)
		var original_length := source.get_length()
		var copy := SoundHandler.one_shot_copy(source)
		var nested_copy := SoundHandler.one_shot_copy(copy)
		assert(is_equal_approx(copy.get_length(), original_length))
		if copy is AudioStreamWAV:
			assert(copy.loop_mode == AudioStreamWAV.LOOP_DISABLED)
		elif copy is AudioStreamMP3:
			assert(not copy.loop)
		var audio := player.play_sound_effect(nested_copy)
		assert(audio.bus == SoundHandler.NES_MIX_BUS)
		assert(is_equal_approx(audio.volume_db, 0.0))
		assert(audio.pitch_scale == 1.0)
		if is_instance_valid(previous):
			assert(not previous.playing)
		previous = audio
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(is_equal_approx(SoundHandler.get_sound(&"coin").get_length(), 53.0 / 60.0))
	assert(is_equal_approx(SoundHandler.get_sound(&"extra_life").get_length(), 48.0 / 60.0))
	var timer_tick := SoundHandler.get_sound(&"timer_tick") as AudioStreamWAV
	assert(is_equal_approx(timer_tick.get_length(), 6.0 / 60.0))
	var raw_timer_sample := roundi(5900 * 8.0 / 15.0)
	var timer_sample := roundi(raw_timer_sample * db_to_linear(-11.78))
	for offset in range(0, timer_tick.data.size(), 2):
		assert(absi(timer_tick.data.decode_s16(offset)) == timer_sample)
	SoundHandler.play_reward(&"coin")
	assert(SoundHandler._square_two.stream == SoundHandler.get_sound(&"coin"))
	assert(SoundHandler._square_two.bus == SoundHandler.NES_MIX_BUS)
	assert(is_equal_approx(SoundHandler._square_two.volume_db, 0.0))
	SoundHandler.play_reward(&"extra_life")
	assert(is_equal_approx(SoundHandler._square_two.volume_db, 0.0))
	SoundHandler.play_reward(&"coin")
	SoundHandler.play_reward(&"timer_tick")
	assert(SoundHandler._square_two.stream == SoundHandler.get_sound(&"extra_life"))
	SoundHandler.stop_reward()
	# Endings use non-positional playback with the same gains and private-copy identity.
	var ending := GameHandler.current_level.ending_presentation as FlagpoleEndingPresentation
	for sample in [ending.flag_sound, ending.music]:
		ending._play_audio(sample)
		assert(ending._audio.bus == SoundHandler.NES_MIX_BUS)
		assert(is_equal_approx(ending._audio.volume_db, 0.0))
		assert((ending._audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	ending._play_audio(null)
	var level := GameHandler.current_level
	assert(level.on_death(player))
	assert(level.death_sequence._audio.playing)
	assert(level.death_sequence._audio.bus == SoundHandler.NES_MIX_BUS)
	assert(is_equal_approx(level.death_sequence._audio.volume_db, 0.0))
	assert(
		(
			(level.death_sequence._audio.stream as AudioStreamWAV).loop_mode
			== AudioStreamWAV.LOOP_DISABLED
		)
	)
	await get_tree().physics_frame
	await get_tree().process_frame
	game.free()
	# Active playback cleanup crosses the audio-server mix boundary.
	for frame in range(6):
		await get_tree().physics_frame
	await get_tree().process_frame
	print(
		"PASS: default SFX gain, one-shot duration/loop preservation, replacement cancellation, pipe copy and death lifecycle playback."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
