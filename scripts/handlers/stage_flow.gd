extends Node
## Runs restart and stage handoffs through the shared transition coordinator.


func restart_after_death(level: BaseLevel, progress_key: String) -> bool:
	if (
		GameHandler.current_level != level
		or GameHandler._current_level_scene == null
		or GameHandler._loading
	):
		return false
	if level.death_reason == BaseLevel.DeathReason.TIMEOUT and not level.time_up_shown:
		return _begin_time_up(level, progress_key)
	if GameHandler.player_status.lives < 0:
		return _begin_game_over(level)
	if GameHandler.transitions.available():
		return (
			GameHandler.transitions.begin(
				level, _restart_death_now.bind(level, progress_key), &"level"
			)
			> 0
		)
	return _restart_death_now(level, progress_key)


func _begin_time_up(level: BaseLevel, progress_key: String) -> bool:
	if not GameHandler.transitions.available():
		level.time_up_shown = true
		return restart_after_death(level, progress_key)
	var source: WeakRef = weakref(level)
	var expected_game: WeakRef = weakref(GameHandler.current_game)
	return (
		GameHandler.transitions.begin(
			GameHandler.current_game,
			_time_up_source_valid.bind(source),
			&"time_up",
			_time_up_finished.bind(expected_game, source, progress_key)
		)
		> 0
	)


func _time_up_source_valid(source: WeakRef) -> bool:
	var level := source.get_ref() as BaseLevel
	return (
		level != null
		and GameHandler.current_level == level
		and not level.is_shutdown
		and level.death_in_progress
	)


func _time_up_finished(
	_success: bool, expected_game: WeakRef, source: WeakRef, progress_key: String
) -> void:
	if (
		GameHandler._detaching
		or expected_game.get_ref() != GameHandler.current_game
		or not _time_up_source_valid(source)
	):
		return
	var level := source.get_ref() as BaseLevel
	# A cancelled notice still resolves the accepted death; never charge again.
	level.time_up_shown = true
	restart_after_death(level, progress_key)


func _restart_death_now(level: BaseLevel, progress_key: String) -> bool:
	if GameHandler.current_level != level or GameHandler._current_level_scene == null:
		return false
	var scene: PackedScene = GameHandler._current_level_scene
	# Shutdown saves the final active snapshot before a deliberate reset.
	level.shutdown()
	if GameHandler.current_level != level:
		return false
	if GameHandler.reset_progress_on_death:
		GameHandler.forget_area_progress(progress_key)
	return GameHandler.load_level(scene)


func transition_to_level(scene: PackedScene) -> bool:
	if scene == null:
		return false
	if GameHandler.transitions.available():
		var transition_owner := (
			GameHandler.current_level as Node
			if is_instance_valid(GameHandler.current_level)
			else GameHandler.current_game
		)
		return (
			GameHandler.transitions.begin(
				transition_owner, GameHandler.load_level.bind(scene), &"level"
			)
			> 0
		)
	return GameHandler.load_level(scene)


func complete_level(level: BaseLevel, override: PackedScene = null) -> bool:
	if (
		GameHandler.current_level != level
		or GameHandler._detaching
		or GameHandler.transitions.busy
		or not is_instance_valid(level)
		or level.is_shutdown
		or not level.completion_in_progress
		or level.completion_dispatched
	):
		return false
	if GameHandler.flow == GameHandler.GameFlow.PLAYING:
		if not GameHandler.claim_completion(level):
			return false
	elif GameHandler.flow != GameHandler.GameFlow.COMPLETING or not level.ending_in_progress:
		return false
	level.completion_dispatched = true
	var expected_game: WeakRef = weakref(GameHandler.current_game)
	var source: WeakRef = weakref(level)
	var destination: PackedScene = override
	var destination_index: int = GameHandler._stage_index(override) if override != null else -1
	if (
		destination == null
		and GameHandler.current_stage_index >= 0
		and GameHandler.current_stage_index + 1 < GameHandler._stages.size()
	):
		destination_index = GameHandler.current_stage_index + 1
		destination = GameHandler._stages[destination_index]
	var operation := _complete_level_now.bind(source, destination, destination_index)
	var finished := finish_completion.bind(expected_game, source)
	if GameHandler.transitions.available():
		var ticket: int = GameHandler.transitions.begin(
			GameHandler.current_game,
			operation,
			&"level" if destination != null else &"finish",
			finished
		)
		if ticket == 0:
			finish_completion(false, expected_game, source)
		return ticket > 0
	var success: bool = operation.call()
	finish_completion(success, expected_game, source)
	return success


func _complete_level_now(source: WeakRef, destination: PackedScene, destination_index: int) -> bool:
	var level := source.get_ref() as BaseLevel
	if (
		GameHandler._detaching
		or GameHandler.flow != GameHandler.GameFlow.COMPLETING
		or level == null
		or GameHandler.current_level != level
		or level.is_shutdown
	):
		return false
	if destination == null:
		return GameHandler.title_flow.show_now(GameHandler.title_flow.first_stage)
	return GameHandler.load_level(destination, true, destination_index)


func finish_completion(_success: bool, expected_game: WeakRef, source: WeakRef) -> void:
	if GameHandler._detaching or expected_game.get_ref() != GameHandler.current_game:
		return
	if (
		GameHandler.flow == GameHandler.GameFlow.TITLE
		and is_instance_valid(GameHandler.title_flow.screen)
	):
		# The coordinator restores its pre-hold entity snapshots first. Title
		# entry has since established a different, persistent gameplay policy.
		GameHandler.title_flow.suspend_background()
		return
	if GameHandler.flow != GameHandler.GameFlow.COMPLETING:
		return
	var level := source.get_ref() as BaseLevel
	if is_instance_valid(level) and GameHandler.current_level == level and not level.is_shutdown:
		if level.ending_in_progress:
			level.cancel_ending()
		else:
			level.completion_in_progress = false
			level.completion_dispatched = false
	GameHandler._set_flow(GameHandler.GameFlow.PLAYING)


func _begin_game_over(level: BaseLevel) -> bool:
	if (
		GameHandler.flow == GameHandler.GameFlow.GAME_OVER
		or not is_instance_valid(GameHandler.current_game)
	):
		return false
	var expected_game: WeakRef = weakref(GameHandler.current_game)
	var source: WeakRef = weakref(level)
	GameHandler._set_flow(GameHandler.GameFlow.GAME_OVER)
	if (
		GameHandler._detaching
		or expected_game.get_ref() != GameHandler.current_game
		or GameHandler.current_level != level
	):
		return false
	if GameHandler.transitions.available():
		var ticket: int = GameHandler.transitions.begin(
			GameHandler.current_game,
			GameHandler._retire_game_over_level.bind(source),
			&"game_over",
			_game_over_finished.bind(expected_game, source)
		)
		if ticket == 0:
			_game_over_finished(false, expected_game, source)
		return ticket > 0
	var success := GameHandler._retire_game_over_level(source)
	_game_over_finished(success, expected_game, source)
	return success


func _game_over_finished(_success: bool, expected_game: WeakRef, source: WeakRef) -> void:
	if (
		GameHandler._detaching
		or expected_game.get_ref() != GameHandler.current_game
		or not is_instance_valid(GameHandler.current_game)
	):
		return
	if GameHandler.flow != GameHandler.GameFlow.GAME_OVER:
		return
	var old_level := source.get_ref() as BaseLevel
	if is_instance_valid(GameHandler.current_level) and GameHandler.current_level != old_level:
		# External replacement owns the new world; stale completion must not replace it.
		GameHandler._set_flow(GameHandler.GameFlow.PLAYING)
		return
	if not GameHandler._retire_game_over_level(source):
		return
	ControllerHandler.consume_menu_confirmation()
	GameHandler.show_title(GameHandler.title_flow.first_stage)
