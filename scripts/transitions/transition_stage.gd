class_name TransitionStage
extends Resource
## One timed presentation after the covered operation succeeds.
@export var phase: StringName = &"presentation"
@export var scene: PackedScene
@export_range(1, 3600, 1) var minimum_frames: int = 1
@export var show_hud: bool = false

func is_valid() -> bool:
 return not phase.is_empty() and minimum_frames > 0 and (scene == null or scene.can_instantiate())
