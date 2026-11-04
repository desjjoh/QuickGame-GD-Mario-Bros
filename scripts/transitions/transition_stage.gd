class_name TransitionStage
extends Resource
## One timed presentation after the covered operation succeeds.
@export var phase: StringName = &"presentation"
@export var scene: PackedScene
@export_range(1, 3600, 1) var minimum_frames: int = 1
@export var show_hud: bool = false
@export var wait_for_presentation: bool = false
@export_range(1, 3600, 1) var completion_timeout_frames: int = 600


func is_valid() -> bool:
	return (
		not phase.is_empty()
		and minimum_frames > 0
		and completion_timeout_frames > 0
		and (scene == null or scene.can_instantiate())
		and (not wait_for_presentation or scene != null)
	)
