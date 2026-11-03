extends Node
## Persistent game entry point. Level instances live inside LevelContainer.

@export var initial_level: PackedScene

@onready var level_container: Node2D = $LevelContainer


func _ready() -> void:
	$SharedShadow.configure(level_container, $UI)
	GameHandler.level_changed.connect($SharedShadow.bind_level)
	GameHandler.attach_game(self, level_container)
	if initial_level == null:
		push_error("Game needs an initial level assigned in the Inspector.")
		return

	GameHandler.load_level(initial_level)


func _exit_tree() -> void:
	if GameHandler.level_changed.is_connected($SharedShadow.bind_level):
		GameHandler.level_changed.disconnect($SharedShadow.bind_level)
	GameHandler.detach_game(self)
