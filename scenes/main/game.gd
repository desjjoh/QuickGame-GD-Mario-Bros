extends Node
## Persistent game entry point. Level instances live inside LevelContainer.

## First gameplay level after Start; the title scene owns its background.
@export var initial_level: PackedScene
@export var start_with_title: bool = true
@export var transitions_enabled: bool = true

@export_group("Presentation")
## Disable the shared shadow shader/compositor pass for frame-pacing comparisons.
@export var shadow_shader_enabled: bool = true:
	set(value):
		shadow_shader_enabled = value
		if is_node_ready():
			$SharedShadow.set_shadow_enabled(value)

@onready var level_container: Node2D = $LevelContainer


func _ready() -> void:
	$SharedShadow.set_shadow_enabled(shadow_shader_enabled)
	$SharedShadow.configure(level_container, $UI)
	GameHandler.level_changed.connect($SharedShadow.bind_level)
	GameHandler.attach_game(self, level_container)
	GameHandler.transitions.attach_game(self, $UI/ScreenContainer/TransitionScreen)
	if initial_level == null:
		push_error("Game needs an initial level assigned in the Inspector.")
		return

	if not GameHandler.start_game_flow(initial_level, start_with_title):
		push_error("Game startup could not create its initial screen.")


func _exit_tree() -> void:
	if GameHandler.level_changed.is_connected($SharedShadow.bind_level):
		GameHandler.level_changed.disconnect($SharedShadow.bind_level)
	GameHandler.detach_game(self)
