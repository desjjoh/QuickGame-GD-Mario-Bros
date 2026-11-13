extends "res://scripts/session/scene_title_flow.gd"
## Connects Mario's title menu, backdrop, and character selection to the title flow.

var first_stage: PackedScene
var starting_stage: PackedScene
var starting_character := GameHandler.PlayerCharacter.MARIO


func detach() -> void:
	super()
	first_stage = null
	starting_stage = null
	starting_character = GameHandler.PlayerCharacter.MARIO


func show_title(first_level: PackedScene) -> bool:
	if (
		GameHandler._detaching
		or first_level == null
		or not is_instance_valid(GameHandler.current_game)
		or GameHandler.transitions.busy
	):
		return false
	return show_now(first_level)


func show_now(first_level: PackedScene) -> bool:
	if not is_instance_valid(GameHandler.current_game):
		return false
	var game := GameHandler.current_game
	var background: PackedScene = game.title_background
	if background == null and not game.stages.is_empty():
		background = game.stages[0]
	if background == null:
		return false
	GameHandler.current_stage_index = -1
	_clear_title()
	first_stage = first_level
	# Runtime loading keeps UI/level dependencies out of autoload construction.
	var title := load("res://scenes/ui/title/title_screen.tscn").instantiate() as Control
	if title == null:
		return false
	screen = title
	GameHandler._set_flow(GameHandler.GameFlow.TITLE)
	# Title entry owns full run cleanup. Save the outgoing snapshot before
	# reset so shutdown cannot repopulate the cleared progress store.
	if is_instance_valid(GameHandler.current_level):
		GameHandler.current_level.shutdown()
	# Promote the completed run before cleanup resets its score.
	GameHandler.set_top_score(maxi(GameHandler.top_score, GameHandler.player_status.score))
	GameHandler.clear_session()
	if not GameHandler.load_level(background):
		_clear_title()
		return false
	GameHandler.current_level.initialize_actors(true)
	suspend_background()
	screen.connect(&"start_requested", _start_selected_character)
	mount_title(
		screen,
		GameHandler.current_game.get_node("UI/ScreenContainer"),
		GameHandler.transitions.busy
	)
	return true


func suspend_background() -> void:
	# The editable title background may contain painted world objects.
	# Freeze their gameplay as well as Mario, while cosmetics remain active.
	for entity in GameHandler.current_level.find_children("*", "BaseEntity", true, false):
		(entity as BaseEntity).set_gameplay_suspended(true)
	GameHandler.current_level.set_physics_process(false)


func _start_selected_character(character: GameHandler.PlayerCharacter) -> void:
	start_new_game(null, character)


func start_new_game(
	destination: PackedScene = null,
	character: GameHandler.PlayerCharacter = GameHandler.PlayerCharacter.MARIO
) -> bool:
	if (
		GameHandler.flow != GameHandler.GameFlow.TITLE
		or GameHandler._detaching
		or not can_start()
		or GameHandler.transitions.busy
	):
		return false
	starting_stage = destination if destination != null else first_stage
	starting_character = character
	ControllerHandler.consume_menu_confirmation()
	GameHandler._set_flow(GameHandler.GameFlow.STARTING)
	return _run_start(_load_starting_stage)


func _get_transition_request() -> Callable:
	return _request_start_transition if GameHandler.transitions.available() else Callable()


func _request_start_transition(operation: Callable, completion: Callable) -> int:
	return GameHandler.transitions.begin(GameHandler.current_game, operation, &"level", completion)


func _load_starting_stage() -> bool:
	if (
		GameHandler.flow != GameHandler.GameFlow.STARTING
		or GameHandler._detaching
		or starting_stage == null
	):
		return false
	# Shutdown saves old progress before the new session deliberately clears it.
	if is_instance_valid(GameHandler.current_level):
		GameHandler.current_level.shutdown()
	var destination := starting_stage
	var character := starting_character
	GameHandler.clear_session()
	GameHandler.player_character = character
	return GameHandler.load_level(destination)


func _reset_start_selection() -> void:
	starting_stage = null
	starting_character = GameHandler.PlayerCharacter.MARIO


func _can_finish_start() -> bool:
	return not GameHandler._detaching and is_instance_valid(GameHandler.current_game)


func _on_start_succeeded() -> void:
	GameHandler._set_flow(GameHandler.GameFlow.PLAYING)


func _on_start_failed() -> void:
	# Cancellation can originate inside a level's _exit_tree. Restore UI
	# only after that tree operation completes, and only for this Game.
	_restore_title.call_deferred(weakref(GameHandler.current_game), first_stage)


func _restore_title(expected_game: WeakRef, first_level: PackedScene) -> void:
	var game := expected_game.get_ref() as Node
	if (
		GameHandler._detaching
		or GameHandler.flow != GameHandler.GameFlow.STARTING
		or not is_instance_valid(game)
		or GameHandler.current_game != game
	):
		return
	show_title(first_level)
