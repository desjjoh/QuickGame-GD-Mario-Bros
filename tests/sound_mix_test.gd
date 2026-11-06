extends Node


func _ready() -> void:
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
		assert(is_equal_approx(audio.volume_db, 0.0))
		assert(audio.pitch_scale == 1.0)
		if is_instance_valid(previous):
			assert(not previous.playing)
		previous = audio
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(is_equal_approx(SoundHandler.get_sound(&"coin").get_length(), 53.0 / 60.0))
	assert(is_equal_approx(SoundHandler.get_sound(&"extra_life").get_length(), 48.0 / 60.0))
	SoundHandler.play_reward(&"coin")
	assert(SoundHandler._square_two.stream == SoundHandler.get_sound(&"coin"))
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
		assert(is_equal_approx(ending._audio.volume_db, 0.0))
		assert((ending._audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	ending._play_audio(null)
	var level := GameHandler.current_level
	assert(level.on_death(player))
	assert(level.death_sequence._audio.playing)
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
	get_tree().quit()
