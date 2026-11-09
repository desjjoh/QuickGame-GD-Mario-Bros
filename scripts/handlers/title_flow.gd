extends Node
## Owns title UI and the pending start transition.

var screen: Control
var first_stage: PackedScene
var starting_stage: PackedScene
var starting_character := GameHandler.PlayerCharacter.MARIO


func detach() -> void:
	_clear_title()
	first_stage = null
	starting_stage = null
	starting_character = GameHandler.PlayerCharacter.MARIO


func reveal() -> void:
	if is_instance_valid(screen):
		screen.show()


func _clear_title() -> void:
	if is_instance_valid(screen):
		screen.hide()
		screen.queue_free()
	screen = null


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
	if GameHandler.transitions.busy:
		screen.hide()
	GameHandler.current_game.get_node("UI/ScreenContainer").add_child(screen)
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
		or not is_instance_valid(screen)
		or GameHandler.transitions.busy
	):
		return false
	if not screen.is_visible_in_tree():
		return false
	starting_stage = destination if destination != null else first_stage
	starting_character = character
	ControllerHandler.consume_menu_confirmation()
	GameHandler._set_flow(GameHandler.GameFlow.STARTING)
	screen.hide()
	if GameHandler.transitions.available():
		var accepted: int = GameHandler.transitions.begin(
			GameHandler.current_game, _load_starting_stage, &"level", _start_finished
		)
		if accepted == 0:
			_start_finished(false)
		return accepted > 0
	var success := _load_starting_stage()
	_start_finished(success)
	return success


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


func _start_finished(success: bool) -> void:
	starting_stage = null
	starting_character = GameHandler.PlayerCharacter.MARIO
	if GameHandler._detaching or not is_instance_valid(GameHandler.current_game):
		return
	if success:
		_clear_title()
		GameHandler._set_flow(GameHandler.GameFlow.PLAYING)
	else:
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
