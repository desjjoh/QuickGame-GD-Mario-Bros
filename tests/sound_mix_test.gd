extends Node

const MIX = preload("res://assets/audio/sound_effect_mix.tres")
const AudioMix = preload("res://scripts/audio/sound_effect_mix.gd")


func _ready() -> void:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	add_child(game)
	var player := GameHandler.current_player
	player.set_gameplay_suspended(true)
	var streams := {
		"res://assets/sfx/smb_jump-small.wav": -3.0,
		"res://assets/sfx/smb_bump.wav": -7.0,
		"res://assets/sfx/smb_pipe.wav": -4.5,
		"res://assets/sfx/smb-skid.mp3": -0.5,
	}
	var previous: AudioStreamPlayer2D
	for path: String in streams:
		var source := load(path) as AudioStream
		var original_length := source.get_length()
		var copy := AudioMix.one_shot_copy(source)
		var nested_copy := AudioMix.one_shot_copy(copy)
		assert(is_equal_approx(MIX.volume_for(source), streams[path]))
		assert(is_equal_approx(MIX.volume_for(nested_copy), streams[path]))
		assert(is_equal_approx(copy.get_length(), original_length))
		if copy is AudioStreamWAV:
			assert(copy.loop_mode == AudioStreamWAV.LOOP_DISABLED)
		elif copy is AudioStreamMP3:
			assert(not copy.loop)
		var audio := player.play_sound_effect(nested_copy)
		assert(is_equal_approx(audio.volume_db, streams[path]))
		assert(audio.pitch_scale == 1.0)
		if is_instance_valid(previous):
			assert(not previous.playing)
		previous = audio
		await get_tree().physics_frame
		await get_tree().process_frame
	# The pipe state's existing private copy also resolves to its original mix.
	assert(is_equal_approx(MIX.volume_for(player.pipe_enter_state.enter_sound_effect), -4.5))
	var level := GameHandler.current_level
	level._start_death_audio()
	assert(level._death_audio.playing)
	assert(is_equal_approx(level._death_audio.volume_db, -8.0))
	assert((level._death_audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	await get_tree().physics_frame
	await get_tree().process_frame
	# Every clocked skid retrigger passes through the same shared playback path.
	var slide := player.state_machine.get_state(&"Slide") as MarioSlideState
	var skid := AudioMix.one_shot_copy(slide.slide_sound)
	for burst in range(3):
		var audio := player.play_sound_effect(skid)
		assert(is_equal_approx(audio.volume_db, -0.5))
		await get_tree().physics_frame
		await get_tree().process_frame
	var unknown := AudioStreamWAV.new()
	assert(MIX.volume_for(unknown) == MIX.master_volume_db)
	game.free()
	# Active playback cleanup crosses the audio-server mix boundary.
	for frame in range(6):
		await get_tree().physics_frame
	await get_tree().process_frame
	print(
		"PASS: shared SFX gains, original/copied source identity, one-shot duration/loop preservation, replacement cancellation, repeated skid gains, pipe copy and death lifecycle playback."
	)
	get_tree().quit()
