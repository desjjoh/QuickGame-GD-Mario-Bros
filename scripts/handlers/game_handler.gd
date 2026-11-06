extends Node
## Global game ownership and in-memory session data. No disk persistence yet.


enum GameFlow { DETACHED, TITLE, STARTING, PLAYING, GAME_OVER, COMPLETING }

signal flow_changed(value: GameFlow)
var flow: GameFlow = GameFlow.DETACHED
var _title_screen: Control
var _first_level: PackedScene
var _start_level: PackedScene
var _stages: Array[PackedScene] = []
var current_stage_index: int = -1
var _detaching: bool = false

signal level_changed(level: BaseLevel)
signal session_value_changed(key: StringName, value: Variant)

var current_game: Node
var current_level: BaseLevel
var current_player: BasePlayer
var _level_container: Node2D
var player_status := PlayerStatus.new()
# App-session record: intentionally survives clear_session(), with no disk saving.
var top_score: int = 0:
	set(value):
		value = clampi(value, 0, 999999)
		if top_score == value:
			return
		top_score = value
		session_value_changed.emit(&"top_score", top_score)

var stage_label: String = "1-1":
	set(value):
		if stage_label == value:
			return
		stage_label = value
		session_value_changed.emit(&"stage_label", stage_label)

var time_remaining: int = 400:
	set(value):
		value = clampi(value, 0, 999)
		if time_remaining == value:
			return
		time_remaining = value
		session_value_changed.emit(&"time_remaining", time_remaining)

var timer_enabled: bool = true:
	set(value):
		if timer_enabled == value:
			return
		timer_enabled = value
		session_value_changed.emit(&"timer_enabled", value)

var _session: Dictionary[StringName, Variant] = {}
var _progress_level_key: String = ""
var _area_progress: Dictionary = {}
var _loading: bool = false
var animation_clock := CosmeticAnimationClock.new()
# Load the coordinator at runtime: it refers back to GameHandler/BaseLevel.
# Keeping it out of this autoload's static dependency graph avoids a script
# resource cycle surviving engine shutdown.
var transitions: Variant
# Global world-progress policy; session counters/lives are unaffected.
var reset_progress_on_death: bool = false
var _current_level_scene: PackedScene


func _ready() -> void:
	player_status.changed_value.connect(_on_player_status_changed)
	transitions = load("res://scripts/handlers/transition_coordinator.gd").new()
	animation_clock.name = "AnimationClock"
	add_child(animation_clock)
	transitions.name = "Transitions"
	add_child(transitions)
	transitions.finished.connect(_on_transition_finished)


func attach_game(game: Node, level_container: Node2D) -> void:
	current_game = game
	_level_container = level_container
	_detaching = false
	_set_flow(GameFlow.DETACHED)


func detach_game(game: Node) -> void:
	if current_game != game:
		return
	_detaching = true
	SoundHandler.stop_reward()
	transitions.detach_game(game)
	_clear_title()
	_first_level = null
	_start_level = null
	_stages.clear()
	current_stage_index = -1
	if is_instance_valid(current_level):
		current_level.shutdown()
	_current_level_scene = null
	current_game = null
	_level_container = null
	current_level = null
	current_player = null
	_set_flow(GameFlow.DETACHED)


func load_level(
	scene: PackedScene, reset_progress: bool = false, stage_index_override: int = -2
) -> bool:
	if _loading or scene == null or not is_instance_valid(_level_container):
		return false
	var instance := scene.instantiate()
	if not instance is BaseLevel:
		push_error("GameHandler can only load scenes inheriting BaseLevel.")
		instance.free()
		return false

	_loading = true
	if is_instance_valid(current_level):
		var previous_level := current_level
		previous_level.shutdown()
		_level_container.remove_child(previous_level)
		previous_level.queue_free()
	_current_level_scene = scene
	current_level = instance as BaseLevel
	if flow != GameFlow.TITLE:
		current_stage_index = (
			_stage_index(scene) if stage_index_override == -2 else stage_index_override
		)
	var level_key := current_level.scene_file_path
	if level_key.is_empty():
		level_key = "runtime:%s" % current_level.get_instance_id()
	select_level_progress(level_key, reset_progress)
	stage_label = current_level.stage_label
	timer_enabled = current_level.timer_enabled
	time_remaining = current_level.starting_time
	current_player = null
	_level_container.add_child(current_level)
	current_player = current_level.player
	_loading = false
	level_changed.emit(current_level)
	_start_current_level_if_ready()
	return true


## Compatibility for existing session consumers; reserved values have one owner.
func set_session_value(key: StringName, value: Variant) -> void:
	match key:
		&"score":
			set_score(int(value))
		&"coins":
			set_coins(int(value))
		&"lives":
			set_lives(int(value))
		&"powerup_form":
			set_player_form(int(value))
		&"top_score":
			set_top_score(int(value))
		&"stage_label":
			stage_label = str(value)
		&"time_remaining":
			time_remaining = int(value)
		&"timer_enabled":
			if is_instance_valid(current_level):
				current_level.timer_enabled = bool(value)
			else:
				timer_enabled = bool(value)
		_:
			_session[key] = value
			session_value_changed.emit(key, value)


func get_session_value(key: StringName, fallback: Variant = null) -> Variant:
	match key:
		&"score":
			return player_status.score
		&"coins":
			return player_status.coins
		&"lives":
			return player_status.lives
		&"powerup_form":
			return player_status.powerup_form
		&"top_score":
			return top_score
		&"stage_label":
			return stage_label
		&"time_remaining":
			return time_remaining
		&"timer_enabled":
			return timer_enabled
	return _session.get(key, fallback)


func _on_player_status_changed(key: StringName, value: int) -> void:
	session_value_changed.emit(key, value)


func set_score(value: int) -> void:
	player_status.score = value


func add_score(amount: int) -> void:
	set_score(player_status.score + amount)


func set_coins(value: int) -> void:
	player_status.coins = value


func add_coins(amount: int) -> void:
	set_coins(player_status.coins + amount)


func award_coin() -> void:
	var total := player_status.coins + 1
	var extra_life := total == 100
	set_coins(total % 100)
	if extra_life:
		set_lives(player_status.lives + 1)
	add_score(200)
	SoundHandler.play_reward(&"extra_life" if extra_life else &"coin")


func set_lives(value: int) -> void:
	player_status.lives = value


func set_player_form(value: PlayerStatus.PowerupForm) -> void:
	player_status.powerup_form = value


func set_top_score(value: int) -> void:
	top_score = value


## Reset the run; app-session top score and authored configuration survive.
func clear_session() -> void:
	SoundHandler.stop_reward()
	current_stage_index = -1
	_start_level = null
	_session.clear()
	clear_level_progress()
	_reset_player_status()
	stage_label = "1-1"
	time_remaining = 400
	timer_enabled = true


func _reset_player_status() -> void:
	if is_instance_valid(current_game):
		player_status.reset(
			current_game.starting_score,
			current_game.starting_coins,
			current_game.starting_lives - 1
		)
	else:
		player_status.reset()


## Select one logical level. Same-level scene recreation preserves its areas.
func select_level_progress(level_key: String, force_reset: bool = false) -> void:
	if force_reset or _progress_level_key != level_key:
		_area_progress.clear()
		_progress_level_key = level_key


func clear_level_progress() -> void:
	_area_progress.clear()
	_progress_level_key = ""


func store_area_progress(
	level_key: String, area_id: StringName, data: Dictionary, source: BaseLevel = null
) -> void:
	if level_key != _progress_level_key:
		return
	if source != null and is_instance_valid(current_level) and source != current_level:
		return
	_area_progress[area_id] = data.duplicate(true)


func get_area_progress(level_key: String, area_id: StringName) -> Dictionary:
	if level_key != _progress_level_key:
		return {}
	return (_area_progress.get(area_id, {}) as Dictionary).duplicate(true)


func forget_area_progress(level_key: String) -> void:
	if level_key == _progress_level_key:
		_area_progress.clear()


func restart_after_death(level: BaseLevel, progress_key: String) -> bool:
	if current_level != level or _current_level_scene == null or _loading:
		return false
	if level.death_reason == BaseLevel.DeathReason.TIMEOUT and not level.time_up_shown:
		return _begin_time_up(level, progress_key)
	if player_status.lives < 0:
		return _begin_game_over(level)
	if transitions.available():
		return transitions.begin(level, _restart_death_now.bind(level, progress_key), &"level") > 0
	return _restart_death_now(level, progress_key)


func _begin_time_up(level: BaseLevel, progress_key: String) -> bool:
	if not transitions.available():
		level.time_up_shown = true
		return restart_after_death(level, progress_key)
	var source: WeakRef = weakref(level)
	var expected_game: WeakRef = weakref(current_game)
	return (
		transitions.begin(
			current_game,
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
		and current_level == level
		and not level.is_shutdown
		and level.death_in_progress
	)


func _time_up_finished(
	_success: bool, expected_game: WeakRef, source: WeakRef, progress_key: String
) -> void:
	if _detaching or expected_game.get_ref() != current_game or not _time_up_source_valid(source):
		return
	var level := source.get_ref() as BaseLevel
	# A cancelled notice still resolves the accepted death; never charge again.
	level.time_up_shown = true
	restart_after_death(level, progress_key)


func _restart_death_now(level: BaseLevel, progress_key: String) -> bool:
	if current_level != level or _current_level_scene == null:
		return false
	var scene := _current_level_scene
	# Shutdown saves the final active snapshot before a deliberate reset.
	level.shutdown()
	if current_level != level:
		return false
	if reset_progress_on_death:
		forget_area_progress(progress_key)
	return load_level(scene)


func transition_to_level(scene: PackedScene) -> bool:
	if scene == null:
		return false
	if transitions.available():
		var transition_owner := (
			current_level as Node if is_instance_valid(current_level) else current_game
		)
		return transitions.begin(transition_owner, load_level.bind(scene), &"level") > 0
	return load_level(scene)


func _set_flow(value: GameFlow) -> void:
	if flow == value:
		return
	flow = value
	flow_changed.emit(value)
	_start_current_level_if_ready()


func _on_transition_finished(_id: int, _success: bool) -> void:
	if flow == GameFlow.TITLE and is_instance_valid(_title_screen):
		_title_screen.show()
	_start_current_level_if_ready()


func _start_current_level_if_ready() -> void:
	if (
		flow == GameFlow.PLAYING
		and not transitions.busy
		and is_instance_valid(current_level)
		and not current_level.is_shutdown
	):
		current_level.on_level_start()


func _clear_title() -> void:
	if is_instance_valid(_title_screen):
		_title_screen.hide()
		_title_screen.queue_free()
	_title_screen = null


func start_game_flow(first_level: PackedScene, with_title: bool = true) -> bool:
	_stages.assign(current_game.stages)
	_first_level = first_level
	if with_title:
		return show_title(first_level)
	_reset_player_status()
	_set_flow(GameFlow.PLAYING)
	return transition_to_level(first_level)


func show_title(first_level: PackedScene) -> bool:
	if _detaching or first_level == null or not is_instance_valid(current_game) or transitions.busy:
		return false
	return _show_title_now(first_level)


func _show_title_now(first_level: PackedScene) -> bool:
	current_stage_index = -1
	_clear_title()
	_first_level = first_level
	# Runtime loading keeps UI/level dependencies out of autoload construction.
	var screen := load("res://scenes/ui/title/title_screen.tscn").instantiate() as Control
	if screen == null:
		return false
	_title_screen = screen
	_set_flow(GameFlow.TITLE)
	# Title entry owns full run cleanup. Save the outgoing snapshot before
	# reset so shutdown cannot repopulate the cleared progress store.
	if is_instance_valid(current_level):
		current_level.shutdown()
	# Promote the completed run before cleanup resets its score.
	set_top_score(maxi(top_score, player_status.score))
	clear_session()
	if not load_level(screen.background_level):
		_clear_title()
		return false
	_suspend_title_background()
	screen.connect(&"start_requested", start_new_game)
	if transitions.busy:
		screen.hide()
	current_game.get_node("UI/ScreenContainer").add_child(screen)
	return true


func _suspend_title_background() -> void:
	# The editable title background may contain painted world objects.
	# Freeze their gameplay as well as Mario, while cosmetics remain active.
	for entity in current_level.find_children("*", "BaseEntity", true, false):
		(entity as BaseEntity).set_gameplay_suspended(true)
	current_level.set_physics_process(false)


func start_new_game(destination: PackedScene = null) -> bool:
	if (
		flow != GameFlow.TITLE
		or _detaching
		or not is_instance_valid(_title_screen)
		or transitions.busy
	):
		return false
	if not _title_screen.is_visible_in_tree():
		return false
	_start_level = destination if destination != null else _first_level
	ControllerHandler.consume_menu_confirmation()
	_set_flow(GameFlow.STARTING)
	_title_screen.hide()
	if transitions.available():
		var accepted: int = transitions.begin(
			current_game, _load_first_level, &"level", _start_finished
		)
		if accepted == 0:
			_start_finished(false)
		return accepted > 0
	var success := _load_first_level()
	_start_finished(success)
	return success


func _load_first_level() -> bool:
	if flow != GameFlow.STARTING or _detaching or _start_level == null:
		return false
	# Shutdown saves old progress before the new session deliberately clears it.
	if is_instance_valid(current_level):
		current_level.shutdown()
	var destination := _start_level
	clear_session()
	return load_level(destination)


func _start_finished(success: bool) -> void:
	_start_level = null
	if _detaching or not is_instance_valid(current_game):
		return
	if success:
		_clear_title()
		_set_flow(GameFlow.PLAYING)
	else:
		# Cancellation can originate inside a level's _exit_tree. Restore UI
		# only after that tree operation completes, and only for this Game.
		_restore_title.call_deferred(weakref(current_game), _first_level)


func _restore_title(expected_game: WeakRef, first_level: PackedScene) -> void:
	var game := expected_game.get_ref() as Node
	if (
		_detaching
		or flow != GameFlow.STARTING
		or not is_instance_valid(game)
		or current_game != game
	):
		return
	show_title(first_level)


func _stage_index(scene: PackedScene) -> int:
	for index in range(_stages.size()):
		if _stages[index] == scene:
			return index
		if (
			not scene.resource_path.is_empty()
			and _stages[index].resource_path == scene.resource_path
		):
			return index
	return -1


func claim_completion(level: BaseLevel) -> bool:
	if (
		flow != GameFlow.PLAYING
		or current_level != level
		or _detaching
		or transitions.busy
		or not is_instance_valid(level)
		or not level.completion_in_progress
	):
		return false
	var expected_game: WeakRef = weakref(current_game)
	var source: WeakRef = weakref(level)
	_set_flow(GameFlow.COMPLETING)
	if not is_instance_valid(level) or current_level != level or level.is_shutdown or _detaching:
		_completion_finished(false, expected_game, source)
		return false
	level.notify_completion_started()
	if not is_instance_valid(level) or current_level != level or level.is_shutdown or _detaching:
		_completion_finished(false, expected_game, source)
		return false
	return true


func cancel_completion(level: BaseLevel) -> void:
	if current_level == level and flow == GameFlow.COMPLETING and not _detaching:
		_set_flow(GameFlow.PLAYING)


func complete_level(level: BaseLevel, override: PackedScene = null) -> bool:
	if (
		current_level != level
		or _detaching
		or transitions.busy
		or not is_instance_valid(level)
		or level.is_shutdown
		or not level.completion_in_progress
		or level.completion_dispatched
	):
		return false
	if flow == GameFlow.PLAYING:
		if not claim_completion(level):
			return false
	elif flow != GameFlow.COMPLETING or not level.ending_in_progress:
		return false
	level.completion_dispatched = true
	var expected_game: WeakRef = weakref(current_game)
	var source: WeakRef = weakref(level)
	var destination: PackedScene = override
	var destination_index := _stage_index(override) if override != null else -1
	if (
		destination == null
		and current_stage_index >= 0
		and current_stage_index + 1 < _stages.size()
	):
		destination_index = current_stage_index + 1
		destination = _stages[destination_index]
	var operation := _complete_level_now.bind(source, destination, destination_index)
	var finished := _completion_finished.bind(expected_game, source)
	if transitions.available():
		var ticket: int = transitions.begin(
			current_game, operation, &"level" if destination != null else &"finish", finished
		)
		if ticket == 0:
			_completion_finished(false, expected_game, source)
		return ticket > 0
	var success: bool = operation.call()
	_completion_finished(success, expected_game, source)
	return success


func _complete_level_now(source: WeakRef, destination: PackedScene, destination_index: int) -> bool:
	var level := source.get_ref() as BaseLevel
	if (
		_detaching
		or flow != GameFlow.COMPLETING
		or level == null
		or current_level != level
		or level.is_shutdown
	):
		return false
	if destination == null:
		return _show_title_now(_first_level)
	return load_level(destination, true, destination_index)


func _completion_finished(_success: bool, expected_game: WeakRef, source: WeakRef) -> void:
	if _detaching or expected_game.get_ref() != current_game:
		return
	if flow == GameFlow.TITLE and is_instance_valid(_title_screen):
		# The coordinator restores its pre-hold entity snapshots first. Title
		# entry has since established a different, persistent gameplay policy.
		_suspend_title_background()
		return
	if flow != GameFlow.COMPLETING:
		return
	var level := source.get_ref() as BaseLevel
	if is_instance_valid(level) and current_level == level and not level.is_shutdown:
		if level.ending_in_progress:
			level.cancel_ending()
		else:
			level.completion_in_progress = false
			level.completion_dispatched = false
	_set_flow(GameFlow.PLAYING)


func _begin_game_over(level: BaseLevel) -> bool:
	if flow == GameFlow.GAME_OVER or not is_instance_valid(current_game):
		return false
	var expected_game: WeakRef = weakref(current_game)
	var source: WeakRef = weakref(level)
	_set_flow(GameFlow.GAME_OVER)
	if _detaching or expected_game.get_ref() != current_game or current_level != level:
		return false
	if transitions.available():
		var ticket: int = transitions.begin(
			current_game,
			_retire_game_over_level.bind(source),
			&"game_over",
			_game_over_finished.bind(expected_game, source)
		)
		if ticket == 0:
			_game_over_finished(false, expected_game, source)
		return ticket > 0
	var success := _retire_game_over_level(source)
	_game_over_finished(success, expected_game, source)
	return success


func _retire_game_over_level(source: WeakRef) -> bool:
	var level := source.get_ref() as BaseLevel
	if is_instance_valid(current_level) and current_level != level:
		return false
	if is_instance_valid(level):
		# Preserve the final snapshot until the return-to-title lifecycle clears it.
		level.shutdown()
		if is_instance_valid(current_level) and current_level != level:
			return false
		if level.get_parent() != null:
			level.get_parent().remove_child(level)
		level.queue_free()
	current_level = null
	current_player = null
	_current_level_scene = null
	return true


func _game_over_finished(_success: bool, expected_game: WeakRef, source: WeakRef) -> void:
	if _detaching or expected_game.get_ref() != current_game or not is_instance_valid(current_game):
		return
	if flow != GameFlow.GAME_OVER:
		return
	var old_level := source.get_ref() as BaseLevel
	if is_instance_valid(current_level) and current_level != old_level:
		# External replacement owns the new world; stale completion must not replace it.
		_set_flow(GameFlow.PLAYING)
		return
	if not _retire_game_over_level(source):
		return
	ControllerHandler.consume_menu_confirmation()
	show_title(_first_level)
