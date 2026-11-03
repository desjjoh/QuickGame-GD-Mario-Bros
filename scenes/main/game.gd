extends Node
## Persistent game entry point. Level instances live inside LevelContainer.

@export var initial_level: PackedScene
@export var transitions_enabled: bool = true

@onready var level_container: Node2D = $LevelContainer


func _ready() -> void:
	$SharedShadow.configure(level_container, $UI)
	GameHandler.level_changed.connect($SharedShadow.bind_level)
	GameHandler.attach_game(self, level_container)
	GameHandler.transitions.attach_game(self, $UI/ScreenContainer/TransitionScreen)
	if initial_level == null:
		push_error("Game needs an initial level assigned in the Inspector.")
		return

	GameHandler.transition_to_level(initial_level)


func _exit_tree() -> void:
	if GameHandler.level_changed.is_connected($SharedShadow.bind_level):
		GameHandler.level_changed.disconnect($SharedShadow.bind_level)
	GameHandler.detach_game(self)
