extends Node
## Persistent game entry point. Level instances live inside LevelContainer.

## Ordered gameplay stages; the title background is configured separately.
@export var stages: Array[PackedScene] = []
## Optional BaseLevel scene for new runs. Empty uses the first stage.
@export var start_stage_override: PackedScene
@export var start_with_title: bool = true
@export var transitions_enabled: bool = true

@export_group("Gameplay")
## Maximum number of live enemies tracked by each level.
@export_range(0, 10, 1, "or_greater") var enemy_limit: int = LevelSpawnRegistry.DEFAULT_ENEMY_LIMIT
## Preserve saved area progress when restarting a stage after losing a life.
@export var save_entity_state_through_death: bool = true

@export_group("Starting Player Status")
@export_range(0, 999999) var starting_score: int = PlayerStatus.DEFAULT_SCORE
@export_range(0, 99) var starting_coins: int = PlayerStatus.DEFAULT_COINS
## Displayed attempts, including the current life.
@export_range(1, 99) var starting_lives: int = PlayerStatus.DEFAULT_LIVES + 1

@export_group("Presentation")
## Optional BaseLevel backdrop for the start menu. Empty uses the first stage.
@export var title_background: PackedScene
## One style for the title, every stage, and standalone level previews.
@export var shadow_style: ShadowStyle:
	set(value):
		shadow_style = value
		if is_node_ready():
			$SharedShadow.set_shadow_style(value)

## Disable the shared shadow shader/compositor pass for frame-pacing comparisons.
@export var shadow_shader_enabled: bool = true:
	set(value):
		shadow_shader_enabled = value
		if is_node_ready():
			$SharedShadow.set_shadow_enabled(value)

@onready var level_container: Node2D = $LevelContainer


func _ready() -> void:
	$SharedShadow.set_shadow_style(shadow_style)
	$SharedShadow.set_shadow_enabled(shadow_shader_enabled)
	$SharedShadow.configure(level_container, $UI)
	GameHandler.level_changed.connect($SharedShadow.bind_level)
	GameHandler.attach_game(self, level_container)
	GameHandler.transitions.attach_game(self, $UI/ScreenContainer/TransitionScreen)
	if stages.is_empty() or stages.has(null):
		push_error("Game needs a nonempty Stages list without empty entries.")
		return

	var first_stage := start_stage_override if start_stage_override != null else stages[0]
	if not GameHandler.start_game_flow(first_stage, start_with_title):
		push_error("Game startup could not create its initial screen.")


func _exit_tree() -> void:
	if GameHandler.level_changed.is_connected($SharedShadow.bind_level):
		GameHandler.level_changed.disconnect($SharedShadow.bind_level)
	GameHandler.detach_game(self)
